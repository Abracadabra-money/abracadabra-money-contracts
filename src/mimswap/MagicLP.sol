/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity >=0.8.0;

import {IERC20Metadata} from "openzeppelin-contracts/interfaces/IERC20Metadata.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {DecimalMath} from "/mimswap/libraries/DecimalMath.sol";
import {Math} from "/mimswap/libraries/Math.sol";
import {PMMPricing} from "/mimswap/libraries/PMMPricing.sol";
import {ICallee} from "/mimswap/interfaces/ICallee.sol";
import {IFeeRateModel} from "/mimswap/interfaces/IFeeRateModel.sol";
import {IWETH} from "interfaces/IWETH.sol";

/// @title MIMSwap MagicLP
/// @author Adapted from DODOEX DSP https://github.com/DODOEX/contractV2/tree/main/contracts/DODOStablePool
contract MagicLP is ERC20, ReentrancyGuard {
    using Math for uint256;
    using SafeCastLib for uint256;
    using SafeTransferLib for address;

    event BuyShares(address to, uint256 increaseShares, uint256 totalShares);
    event SellShares(address payer, address to, uint256 decreaseShares, uint256 totalShares);
    event Swap(address fromToken, address toToken, uint256 fromAmount, uint256 toAmount, address trader, address receiver);
    event FlashLoan(address borrower, address assetTo, uint256 baseAmount, uint256 quoteAmount);
    event RChange(PMMPricing.RState newRState);
    event Mint(address indexed user, uint256 value);
    event Burn(address indexed user, uint256 value);

    error ErrInitialized();
    error ErrBaseQuoteSame();
    error ErrInvalidI();
    error ErrInvalidK();
    error ErrExpired();
    error ErrInvalidSignature();
    error ErrFlashLoanFailed();
    error ErrNoBaseInput();
    error ErrZeroAddress();
    error ErrZeroQuoteAmount();
    error ErrMintAmountNotEnough();
    error ErrNotEnough();
    error ErrWithdrawNotEnough();
    error ErrSellBackNotAllowed();

    uint256 public constant MAX_I = 10 ** 36;
    uint256 public constant MAX_K = 10 ** 18;

    bool internal _INITIALIZED_;

    address public _MAINTAINER_;
    address public _BASE_TOKEN_;
    address public _QUOTE_TOKEN_;
    uint112 public _BASE_RESERVE_;
    uint112 public _QUOTE_RESERVE_;
    uint32 public _BLOCK_TIMESTAMP_LAST_;
    uint256 public _BASE_PRICE_CUMULATIVE_LAST_;
    uint112 public _BASE_TARGET_;
    uint112 public _QUOTE_TARGET_;
    uint32 public _RState_;
    IFeeRateModel public _MT_FEE_RATE_MODEL_;
    uint256 public _LP_FEE_RATE_;
    uint256 public _K_;
    uint256 public _I_;

    function init(
        address maintainer,
        address baseTokenAddress,
        address quoteTokenAddress,
        uint256 lpFeeRate,
        address mtFeeRateModel,
        uint256 i,
        uint256 k
    ) external {
        if (_INITIALIZED_) {
            revert ErrInitialized();
        }

        _INITIALIZED_ = true;

        if (baseTokenAddress == quoteTokenAddress) {
            revert ErrBaseQuoteSame();
        }
        if (i == 0 || i > MAX_I) {
            revert ErrInvalidI();
        }
        if (k > MAX_K) {
            revert ErrInvalidK();
        }

        _BASE_TOKEN_ = baseTokenAddress;
        _QUOTE_TOKEN_ = quoteTokenAddress;
        _I_ = i;
        _K_ = k;
        _LP_FEE_RATE_ = lpFeeRate;
        _MT_FEE_RATE_MODEL_ = IFeeRateModel(mtFeeRateModel);
        _MAINTAINER_ = maintainer;
        _BLOCK_TIMESTAMP_LAST_ = uint32(block.timestamp % 2 ** 32);

        _afterInitialized();
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// PUBLIC
    //////////////////////////////////////////////////////////////////////////////////////

    function sync() external nonReentrant {
        _sync();
    }

    function correctRState() external {
        if (_RState_ == uint32(PMMPricing.RState.BELOW_ONE) && _BASE_RESERVE_ < _BASE_TARGET_) {
            _RState_ = uint32(PMMPricing.RState.ONE);
            _BASE_TARGET_ = _BASE_RESERVE_;
            _QUOTE_TARGET_ = _QUOTE_RESERVE_;
        }
        if (_RState_ == uint32(PMMPricing.RState.ABOVE_ONE) && _QUOTE_RESERVE_ < _QUOTE_TARGET_) {
            _RState_ = uint32(PMMPricing.RState.ONE);
            _BASE_TARGET_ = _BASE_RESERVE_;
            _QUOTE_TARGET_ = _QUOTE_RESERVE_;
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////

    function name() public view override returns (string memory) {
        return string(abi.encodePacked("MagicLP ", IERC20Metadata(_BASE_TOKEN_).symbol(), "/", IERC20Metadata(_QUOTE_TOKEN_).symbol()));
    }

    function symbol() public pure override returns (string memory) {
        return "MagicLP";
    }

    function decimals() public view override returns (uint8) {
        return IERC20Metadata(_BASE_TOKEN_).decimals();
    }

    function querySellBase(
        address trader,
        uint256 payBaseAmount
    ) public view returns (uint256 receiveQuoteAmount, uint256 mtFee, PMMPricing.RState newRState, uint256 newBaseTarget) {
        PMMPricing.PMMState memory state = getPMMState();
        (receiveQuoteAmount, newRState) = PMMPricing.sellBaseToken(state, payBaseAmount);

        uint256 lpFeeRate = _LP_FEE_RATE_;
        uint256 mtFeeRate = _MT_FEE_RATE_MODEL_.getFeeRate(trader);
        mtFee = DecimalMath.mulFloor(receiveQuoteAmount, mtFeeRate);
        receiveQuoteAmount = receiveQuoteAmount - DecimalMath.mulFloor(receiveQuoteAmount, lpFeeRate) - mtFee;
        newBaseTarget = state.B0;
    }

    function querySellQuote(
        address trader,
        uint256 payQuoteAmount
    ) public view returns (uint256 receiveBaseAmount, uint256 mtFee, PMMPricing.RState newRState, uint256 newQuoteTarget) {
        PMMPricing.PMMState memory state = getPMMState();
        (receiveBaseAmount, newRState) = PMMPricing.sellQuoteToken(state, payQuoteAmount);

        uint256 lpFeeRate = _LP_FEE_RATE_;
        uint256 mtFeeRate = _MT_FEE_RATE_MODEL_.getFeeRate(trader);
        mtFee = DecimalMath.mulFloor(receiveBaseAmount, mtFeeRate);
        receiveBaseAmount = receiveBaseAmount - DecimalMath.mulFloor(receiveBaseAmount, lpFeeRate) - mtFee;
        newQuoteTarget = state.Q0;
    }

    function getPMMState() public view returns (PMMPricing.PMMState memory state) {
        state.i = _I_;
        state.K = _K_;
        state.B = _BASE_RESERVE_;
        state.Q = _QUOTE_RESERVE_;
        state.B0 = _BASE_TARGET_; // will be calculated in adjustedTarget
        state.Q0 = _QUOTE_TARGET_;
        state.R = PMMPricing.RState(_RState_);
        PMMPricing.adjustedTarget(state);
    }

    function getPMMStateForCall() external view returns (uint256 i, uint256 K, uint256 B, uint256 Q, uint256 B0, uint256 Q0, uint256 R) {
        PMMPricing.PMMState memory state = getPMMState();
        i = state.i;
        K = state.K;
        B = state.B;
        Q = state.Q;
        B0 = state.B0;
        Q0 = state.Q0;
        R = uint256(state.R);
    }

    function getMidPrice() public view returns (uint256 midPrice) {
        return PMMPricing.getMidPrice(getPMMState());
    }

    function getVaultReserve() external view returns (uint256 baseReserve, uint256 quoteReserve) {
        baseReserve = _BASE_RESERVE_;
        quoteReserve = _QUOTE_RESERVE_;
    }

    function getUserFeeRate(address user) external view returns (uint256 lpFeeRate, uint256 mtFeeRate) {
        lpFeeRate = _LP_FEE_RATE_;
        mtFeeRate = _MT_FEE_RATE_MODEL_.getFeeRate(user);
    }

    function getBaseInput() public view returns (uint256 input) {
        return _BASE_TOKEN_.balanceOf(address(this)) - uint256(_BASE_RESERVE_);
    }

    function getQuoteInput() public view returns (uint256 input) {
        return _QUOTE_TOKEN_.balanceOf(address(this)) - uint256(_QUOTE_RESERVE_);
    }

    function version() external virtual pure returns (string memory) {
        return "MagicLP 1.0.0";
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// TRADE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////////////////

    function sellBase(address to) external nonReentrant returns (uint256 receiveQuoteAmount) {
        uint256 baseBalance = _BASE_TOKEN_.balanceOf(address(this));
        uint256 baseInput = baseBalance - uint256(_BASE_RESERVE_);
        uint256 mtFee;
        uint256 newBaseTarget;
        PMMPricing.RState newRState;
        (receiveQuoteAmount, mtFee, newRState, newBaseTarget) = querySellBase(tx.origin, baseInput);

        _transferQuoteOut(to, receiveQuoteAmount);
        _transferQuoteOut(_MAINTAINER_, mtFee);

        // update TARGET
        if (_RState_ != uint32(newRState)) {
            _BASE_TARGET_ = newBaseTarget.toUint112();
            _RState_ = uint32(newRState);
            emit RChange(newRState);
        }

        _setReserve(baseBalance, _QUOTE_TOKEN_.balanceOf(address(this)));

        emit Swap(address(_BASE_TOKEN_), address(_QUOTE_TOKEN_), baseInput, receiveQuoteAmount, msg.sender, to);
    }

    function sellQuote(address to) external nonReentrant returns (uint256 receiveBaseAmount) {
        uint256 quoteBalance = _QUOTE_TOKEN_.balanceOf(address(this));
        uint256 quoteInput = quoteBalance - uint256(_QUOTE_RESERVE_);
        uint256 mtFee;
        uint256 newQuoteTarget;
        PMMPricing.RState newRState;
        (receiveBaseAmount, mtFee, newRState, newQuoteTarget) = querySellQuote(tx.origin, quoteInput);

        _transferBaseOut(to, receiveBaseAmount);
        _transferBaseOut(_MAINTAINER_, mtFee);

        // update TARGET
        if (_RState_ != uint32(newRState)) {
            _QUOTE_TARGET_ = newQuoteTarget.toUint112();
            _RState_ = uint32(newRState);
            emit RChange(newRState);
        }

        _setReserve(_BASE_TOKEN_.balanceOf(address(this)), quoteBalance);

        emit Swap(address(_QUOTE_TOKEN_), address(_BASE_TOKEN_), quoteInput, receiveBaseAmount, msg.sender, to);
    }

    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external nonReentrant {
        _transferBaseOut(assetTo, baseAmount);
        _transferQuoteOut(assetTo, quoteAmount);

        if (data.length > 0) {
            ICallee(assetTo).FlashLoanCall(msg.sender, baseAmount, quoteAmount, data);
        }

        uint256 baseBalance = _BASE_TOKEN_.balanceOf(address(this));
        uint256 quoteBalance = _QUOTE_TOKEN_.balanceOf(address(this));

        // no input -> pure loss
        if (baseBalance < _BASE_RESERVE_ && quoteBalance < _QUOTE_RESERVE_) {
            revert ErrFlashLoanFailed();
        }

        // sell quote case
        // quote input + base output
        if (baseBalance < _BASE_RESERVE_) {
            uint256 quoteInput = quoteBalance - uint256(_QUOTE_RESERVE_);
            (uint256 receiveBaseAmount, uint256 mtFee, PMMPricing.RState newRState, uint256 newQuoteTarget) = querySellQuote(
                tx.origin,
                quoteInput
            );

            if (uint256(_BASE_RESERVE_) - baseBalance > receiveBaseAmount) {
                revert ErrFlashLoanFailed();
            }

            _transferBaseOut(_MAINTAINER_, mtFee);
            if (_RState_ != uint32(newRState)) {
                _QUOTE_TARGET_ = newQuoteTarget.toUint112();
                _RState_ = uint32(newRState);
                emit RChange(newRState);
            }
            emit Swap(address(_QUOTE_TOKEN_), address(_BASE_TOKEN_), quoteInput, receiveBaseAmount, msg.sender, assetTo);
        }

        // sell base case
        // base input + quote output
        if (quoteBalance < _QUOTE_RESERVE_) {
            uint256 baseInput = baseBalance - uint256(_BASE_RESERVE_);
            (uint256 receiveQuoteAmount, uint256 mtFee, PMMPricing.RState newRState, uint256 newBaseTarget) = querySellBase(
                tx.origin,
                baseInput
            );

            if (uint256(_QUOTE_RESERVE_) - quoteBalance > receiveQuoteAmount) {
                revert ErrFlashLoanFailed();
            }

            _transferQuoteOut(_MAINTAINER_, mtFee);
            if (_RState_ != uint32(newRState)) {
                _BASE_TARGET_ = newBaseTarget.toUint112();
                _RState_ = uint32(newRState);
                emit RChange(newRState);
            }
            emit Swap(address(_BASE_TOKEN_), address(_QUOTE_TOKEN_), baseInput, receiveQuoteAmount, msg.sender, assetTo);
        }

        _sync();

        emit FlashLoan(msg.sender, assetTo, baseAmount, quoteAmount);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// BUY & SELL SHARES
    //////////////////////////////////////////////////////////////////////////////////////

    // buy shares [round down]
    function buyShares(address to) external nonReentrant returns (uint256 shares, uint256 baseInput, uint256 quoteInput) {
        uint256 baseBalance = _BASE_TOKEN_.balanceOf(address(this));
        uint256 quoteBalance = _QUOTE_TOKEN_.balanceOf(address(this));
        uint256 baseReserve = _BASE_RESERVE_;
        uint256 quoteReserve = _QUOTE_RESERVE_;

        baseInput = baseBalance - baseReserve;
        quoteInput = quoteBalance - quoteReserve;

        if (baseInput == 0) {
            revert ErrNoBaseInput();
        }

        // Round down when withdrawing. Therefore, never be a situation occuring balance is 0 but totalsupply is not 0
        // But May Happen，reserve >0 But totalSupply = 0
        if (totalSupply() == 0) {
            // case 1. initial supply
            if (quoteBalance == 0) {
                revert ErrZeroQuoteAmount();
            }

            shares = quoteBalance < DecimalMath.mulFloor(baseBalance, _I_) ? DecimalMath.divFloor(quoteBalance, _I_) : baseBalance;
            _BASE_TARGET_ = uint112(shares);
            _QUOTE_TARGET_ = uint112(DecimalMath.mulFloor(shares, _I_));

            if (shares <= 2001) {
                revert ErrMintAmountNotEnough();
            }

            _mint(address(0), 1001);
            shares -= 1001;
        } else if (baseReserve > 0 && quoteReserve > 0) {
            // case 2. normal case
            uint256 baseInputRatio = DecimalMath.divFloor(baseInput, baseReserve);
            uint256 quoteInputRatio = DecimalMath.divFloor(quoteInput, quoteReserve);
            uint256 mintRatio = quoteInputRatio < baseInputRatio ? quoteInputRatio : baseInputRatio;
            shares = DecimalMath.mulFloor(totalSupply(), mintRatio);

            _BASE_TARGET_ = uint112(uint256(_BASE_TARGET_) + DecimalMath.mulFloor(uint256(_BASE_TARGET_), mintRatio));
            _QUOTE_TARGET_ = uint112(uint256(_QUOTE_TARGET_) + DecimalMath.mulFloor(uint256(_QUOTE_TARGET_), mintRatio));
        }

        _mint(to, shares);
        _setReserve(baseBalance, quoteBalance);

        emit BuyShares(to, shares, balanceOf(to));
    }

    // sell shares [round down]
    function sellShares(
        uint256 shareAmount,
        address to,
        uint256 baseMinAmount,
        uint256 quoteMinAmount,
        bytes calldata data,
        uint256 deadline
    ) external nonReentrant returns (uint256 baseAmount, uint256 quoteAmount) {
        if (deadline < block.timestamp) {
            revert ErrExpired();
        }
        if (shareAmount > balanceOf(msg.sender)) {
            revert ErrNotEnough();
        }
        if (to == address(this)) {
            revert ErrSellBackNotAllowed();
        }

        uint256 baseBalance = _BASE_TOKEN_.balanceOf(address(this));
        uint256 quoteBalance = _QUOTE_TOKEN_.balanceOf(address(this));
        uint256 totalShares = totalSupply();

        baseAmount = (baseBalance * shareAmount) / totalShares;
        quoteAmount = (quoteBalance * shareAmount) / totalShares;

        _BASE_TARGET_ = uint112(uint256(_BASE_TARGET_) - (uint256(_BASE_TARGET_) * shareAmount).divCeil(totalShares));
        _QUOTE_TARGET_ = uint112(uint256(_QUOTE_TARGET_) - (uint256(_QUOTE_TARGET_) * shareAmount).divCeil(totalShares));

        if (baseAmount < baseMinAmount || quoteAmount < quoteMinAmount) {
            revert ErrWithdrawNotEnough();
        }

        _burn(msg.sender, shareAmount);
        _transferBaseOut(to, baseAmount);
        _transferQuoteOut(to, quoteAmount);
        _sync();

        if (data.length > 0) {
            ICallee(to).SellShareCall(msg.sender, shareAmount, baseAmount, quoteAmount, data);
        }

        emit SellShares(msg.sender, to, shareAmount, balanceOf(msg.sender));
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////

    function _twapUpdate() internal {
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - _BLOCK_TIMESTAMP_LAST_;

        if (timeElapsed > 0 && _BASE_RESERVE_ != 0 && _QUOTE_RESERVE_ != 0) {
            _BASE_PRICE_CUMULATIVE_LAST_ += getMidPrice() * timeElapsed;
        }

        _BLOCK_TIMESTAMP_LAST_ = blockTimestamp;
    }

    function _setReserve(uint256 baseReserve, uint256 quoteReserve) internal {
        _BASE_RESERVE_ = baseReserve.toUint112();
        _QUOTE_RESERVE_ = quoteReserve.toUint112();

        _twapUpdate();
    }

    function _sync() internal {
        uint256 baseBalance = _BASE_TOKEN_.balanceOf(address(this));
        uint256 quoteBalance = _QUOTE_TOKEN_.balanceOf(address(this));

        if (baseBalance != _BASE_RESERVE_) {
            _BASE_RESERVE_ = baseBalance.toUint112();
        }
        if (quoteBalance != _QUOTE_RESERVE_) {
            _QUOTE_RESERVE_ = quoteBalance.toUint112();
        }

        _twapUpdate();
    }

    function _transferBaseOut(address to, uint256 amount) internal {
        if (amount > 0) {
            _BASE_TOKEN_.safeTransfer(to, amount);
        }
    }

    function _transferQuoteOut(address to, uint256 amount) internal {
        if (amount > 0) {
            _QUOTE_TOKEN_.safeTransfer(to, amount);
        }
    }

    function _mint(address to, uint256 amount) internal override {
        if (amount <= 1000) {
            revert ErrMintAmountNotEnough();
        }

        super._mint(to, amount);
    }

    function _afterInitialized() internal virtual {}
}
