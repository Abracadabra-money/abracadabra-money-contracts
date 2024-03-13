/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
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
contract MagicLP is ERC20, ReentrancyGuard, Owned {
    using Math for uint256;
    using SafeCastLib for uint256;
    using SafeTransferLib for address;

    event BuyShares(address to, uint256 increaseShares, uint256 totalShares);
    event SellShares(address payer, address to, uint256 decreaseShares, uint256 totalShares);
    event Swap(address fromToken, address toToken, uint256 fromAmount, uint256 toAmount, address trader, address receiver);
    event FlashLoan(address borrower, address assetTo, uint256 baseAmount, uint256 quoteAmount);
    event RChange(PMMPricing.RState newRState);
    event TokenRescue(address indexed token, address to, uint256 amount);
    event ParametersChanged(uint256 newLpFeeRate, uint256 newI, uint256 newK, uint256 newBaseReserve, uint256 newQuoteReserve);
    event PausedChanged(bool paused);
    event OperatorChanged(address indexed operator, bool status);

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
    error ErrZeroQuoteTarget();
    error ErrMintAmountNotEnough();
    error ErrNotEnough();
    error ErrWithdrawNotEnough();
    error ErrSellBackNotAllowed();
    error ErrInvalidLPFeeRate();
    error ErrNotImplementationOwner();
    error ErrNotImplementation();
    error ErrNotClone();
    error ErrNotAllowed();
    error ErrReserveAmountNotEnough();
    error ErrOverflow();
    error ErrNotPaused();
    error ErrNotAllowedImplementationOperator();
    error ErrInvalidTargets();
    
    MagicLP public immutable implementation;

    uint256 public constant MAX_I = 10 ** 36;
    uint256 public constant MAX_K = 10 ** 18;
    uint256 public constant MIN_LP_FEE_RATE = 1e14; // 0.01%
    uint256 public constant MAX_LP_FEE_RATE = 1e16; // 1%

    bool internal _INITIALIZED_;
    bool public _PAUSED_;
    bool public _PROTOCOL_OWNED_POOL_;

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

    mapping(address => bool) public operators;

    constructor(address owner_) Owned(owner_) {
        implementation = this;

        // prevents the implementation contract initialization
        _INITIALIZED_ = true;
    }

    function init(
        address baseTokenAddress,
        address quoteTokenAddress,
        uint256 lpFeeRate,
        address mtFeeRateModel,
        uint256 i,
        uint256 k,
        bool protocolOwnedPool
    ) external {
        if (_INITIALIZED_) {
            revert ErrInitialized();
        }
        if (mtFeeRateModel == address(0) || baseTokenAddress == address(0) || quoteTokenAddress == address(0)) {
            revert ErrZeroAddress();
        }
        if (baseTokenAddress == quoteTokenAddress) {
            revert ErrBaseQuoteSame();
        }
        if (i == 0 || i > MAX_I) {
            revert ErrInvalidI();
        }
        if (k > MAX_K) {
            revert ErrInvalidK();
        }
        if (lpFeeRate < MIN_LP_FEE_RATE || lpFeeRate > MAX_LP_FEE_RATE) {
            revert ErrInvalidLPFeeRate();
        }

        _INITIALIZED_ = true;
        _BASE_TOKEN_ = baseTokenAddress;
        _QUOTE_TOKEN_ = quoteTokenAddress;
        _I_ = i;
        _K_ = k;
        _LP_FEE_RATE_ = lpFeeRate;
        _MT_FEE_RATE_MODEL_ = IFeeRateModel(mtFeeRateModel);
        _BLOCK_TIMESTAMP_LAST_ = uint32(block.timestamp % 2 ** 32);
        _PROTOCOL_OWNED_POOL_ = protocolOwnedPool;

        _afterInitialized();
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// PUBLIC - CLONES ONLY
    //////////////////////////////////////////////////////////////////////////////////////

    function sync() external nonReentrant onlyClones {
        _sync();
    }

    function correctRState() external onlyClones {
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

    function isImplementationOperator(address _operator) public view returns (bool) {
        return implementation.operators(_operator) || _operator == implementation.owner();
    }

    function querySellBase(
        address trader,
        uint256 payBaseAmount
    ) public view returns (uint256 receiveQuoteAmount, uint256 mtFee, PMMPricing.RState newRState, uint256 newBaseTarget) {
        PMMPricing.PMMState memory state = getPMMState();
        (receiveQuoteAmount, newRState) = PMMPricing.sellBaseToken(state, payBaseAmount);

        (uint256 lpFeeRate, uint256 mtFeeRate) = _MT_FEE_RATE_MODEL_.getFeeRate(trader, _LP_FEE_RATE_);
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

        (uint256 lpFeeRate, uint256 mtFeeRate) = _MT_FEE_RATE_MODEL_.getFeeRate(trader, _LP_FEE_RATE_);
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

    function getReserves() external view returns (uint256 baseReserve, uint256 quoteReserve) {
        baseReserve = _BASE_RESERVE_;
        quoteReserve = _QUOTE_RESERVE_;
    }

    function getUserFeeRate(address user) external view returns (uint256 lpFeeRate, uint256 mtFeeRate) {
        return _MT_FEE_RATE_MODEL_.getFeeRate(user, _LP_FEE_RATE_);
    }

    function getBaseInput() public view nonReadReentrant returns (uint256 input) {
        return _BASE_TOKEN_.balanceOf(address(this)) - uint256(_BASE_RESERVE_);
    }

    function getQuoteInput() public view nonReadReentrant returns (uint256 input) {
        return _QUOTE_TOKEN_.balanceOf(address(this)) - uint256(_QUOTE_RESERVE_);
    }

    function version() external pure virtual returns (string memory) {
        return "MagicLP 1.0.0";
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// TRADE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////////////////

    function sellBase(address to) external nonReentrant onlyClones whenNotPaused returns (uint256 receiveQuoteAmount) {
        uint256 baseBalance = _BASE_TOKEN_.balanceOf(address(this));
        uint256 baseInput = baseBalance - uint256(_BASE_RESERVE_);
        uint256 mtFee;
        uint256 newBaseTarget;
        PMMPricing.RState newRState;
        (receiveQuoteAmount, mtFee, newRState, newBaseTarget) = querySellBase(tx.origin, baseInput);

        _transferQuoteOut(to, receiveQuoteAmount);
        _transferQuoteOut(_MT_FEE_RATE_MODEL_.maintainer(), mtFee);

        // update TARGET
        if (_RState_ != uint32(newRState)) {
            _BASE_TARGET_ = newBaseTarget.toUint112();
            _RState_ = uint32(newRState);
            emit RChange(newRState);
        }

        _setReserve(baseBalance, _QUOTE_TOKEN_.balanceOf(address(this)));

        emit Swap(address(_BASE_TOKEN_), address(_QUOTE_TOKEN_), baseInput, receiveQuoteAmount, msg.sender, to);
    }

    function sellQuote(address to) external nonReentrant onlyClones whenNotPaused returns (uint256 receiveBaseAmount) {
        uint256 quoteBalance = _QUOTE_TOKEN_.balanceOf(address(this));
        uint256 quoteInput = quoteBalance - uint256(_QUOTE_RESERVE_);
        uint256 mtFee;
        uint256 newQuoteTarget;
        PMMPricing.RState newRState;
        (receiveBaseAmount, mtFee, newRState, newQuoteTarget) = querySellQuote(tx.origin, quoteInput);

        _transferBaseOut(to, receiveBaseAmount);
        _transferBaseOut(_MT_FEE_RATE_MODEL_.maintainer(), mtFee);

        // update TARGET
        if (_RState_ != uint32(newRState)) {
            _QUOTE_TARGET_ = newQuoteTarget.toUint112();
            _RState_ = uint32(newRState);
            emit RChange(newRState);
        }

        _setReserve(_BASE_TOKEN_.balanceOf(address(this)), quoteBalance);

        emit Swap(address(_QUOTE_TOKEN_), address(_BASE_TOKEN_), quoteInput, receiveBaseAmount, msg.sender, to);
    }

    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external nonReentrant onlyClones whenNotPaused {
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

            _transferBaseOut(_MT_FEE_RATE_MODEL_.maintainer(), mtFee);
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

            _transferQuoteOut(_MT_FEE_RATE_MODEL_.maintainer(), mtFee);
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
    function buyShares(address to) external nonReentrant onlyClones whenNotPaused returns (uint256 shares, uint256 baseInput, uint256 quoteInput) {
        uint256 baseBalance = _BASE_TOKEN_.balanceOf(address(this));
        uint256 quoteBalance = _QUOTE_TOKEN_.balanceOf(address(this));
        uint256 baseReserve = _BASE_RESERVE_;
        uint256 quoteReserve = _QUOTE_RESERVE_;

        baseInput = baseBalance - baseReserve;
        quoteInput = quoteBalance - quoteReserve;

        if (baseInput == 0) {
            revert ErrNoBaseInput();
        }

        // Round down when withdrawing. Therefore, never be a situation occurring balance is 0 but totalsupply is not 0
        // But May Happen，reserve >0 But totalSupply = 0
        if (totalSupply() == 0) {
            // case 1. initial supply
            if (quoteBalance == 0) {
                revert ErrZeroQuoteAmount();
            }

            shares = quoteBalance < DecimalMath.mulFloor(baseBalance, _I_) ? DecimalMath.divFloor(quoteBalance, _I_) : baseBalance;
            _BASE_TARGET_ = shares.toUint112();
            _QUOTE_TARGET_ = DecimalMath.mulFloor(shares, _I_).toUint112();

            if (_QUOTE_TARGET_ == 0) {
                revert ErrZeroQuoteTarget();
            }

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

            _BASE_TARGET_ = (uint256(_BASE_TARGET_) + DecimalMath.mulFloor(uint256(_BASE_TARGET_), mintRatio)).toUint112();
            _QUOTE_TARGET_ = (uint256(_QUOTE_TARGET_) + DecimalMath.mulFloor(uint256(_QUOTE_TARGET_), mintRatio)).toUint112();
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
    ) external nonReentrant onlyClones whenNotPaused returns (uint256 baseAmount, uint256 quoteAmount) {
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
    /// ADMIN - IMPLEMENTATION ONLY
    //////////////////////////////////////////////////////////////////////////////////////

    function setOperator(address _operator, bool _status) external onlyImplementation onlyImplementationOwner {
        operators[_operator] = _status;
        emit OperatorChanged(_operator, _status);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS / ADMIN - PROTOCOL OWNED POOL AND CLONES ONLY
    //////////////////////////////////////////////////////////////////////////////////////

    function setPaused(bool paused) external onlyClones onlyProtocolOwnedPool onlyImplementationOperators {
        _PAUSED_ = paused;
        emit PausedChanged(paused);
    }

    function rescue(address token, address to, uint256 amount) external onlyClones onlyProtocolOwnedPool onlyImplementationOperators {
        if (token == _BASE_TOKEN_ || token == _QUOTE_TOKEN_) {
            revert ErrNotAllowed();
        }

        token.safeTransfer(to, amount);
        emit TokenRescue(token, to, amount);
    }

    /// @notice Set new parameters for the pool
    /// The pool must be paused, preferably blocks earlier to avoid sandwiching
    function setParameters(
        address assetTo,
        uint256 newLpFeeRate,
        uint256 newI,
        uint256 newK,
        uint256 baseOutAmount,
        uint256 quoteOutAmount,
        uint256 minBaseReserve,
        uint256 minQuoteReserve
    ) public nonReentrant onlyClones whenPaused onlyProtocolOwnedPool onlyImplementationOperators {
        if (_BASE_RESERVE_ < minBaseReserve || _QUOTE_RESERVE_ < minQuoteReserve) {
            revert ErrReserveAmountNotEnough();
        }
        if (newI == 0 || newI > MAX_I) {
            revert ErrInvalidI();
        }
        if (newK > MAX_K) {
            revert ErrInvalidK();
        }
        if (newLpFeeRate < MIN_LP_FEE_RATE || newLpFeeRate > MAX_LP_FEE_RATE) {
            revert ErrInvalidLPFeeRate();
        }

        _LP_FEE_RATE_ = newLpFeeRate;
        _K_ = newK;
        _I_ = newI;

        _transferBaseOut(assetTo, baseOutAmount);
        _transferQuoteOut(assetTo, quoteOutAmount);
        (uint256 newBaseBalance, uint256 newQuoteBalance) = _resetTargetAndReserve();

        emit ParametersChanged(newLpFeeRate, newI, newK, newBaseBalance, newQuoteBalance);
    }

    function ratioSync() external nonReentrant onlyClones onlyProtocolOwnedPool onlyImplementationOperators {
        uint256 baseBalance = _BASE_TOKEN_.balanceOf(address(this));
        uint256 quoteBalance = _QUOTE_TOKEN_.balanceOf(address(this));

        if (baseBalance > type(uint112).max || quoteBalance > type(uint112).max) {
            revert ErrOverflow();
        }

        if (baseBalance != _BASE_RESERVE_) {
            _BASE_TARGET_ = uint112((uint256(_BASE_TARGET_) * baseBalance) / uint256(_BASE_RESERVE_));
            _BASE_RESERVE_ = uint112(baseBalance);
        }
        if (quoteBalance != _QUOTE_RESERVE_) {
            _QUOTE_TARGET_ = uint112((uint256(_QUOTE_TARGET_) * quoteBalance) / uint256(_QUOTE_RESERVE_));
            _QUOTE_RESERVE_ = uint112(quoteBalance);
        }

        if(_BASE_TARGET_ == 0 || _QUOTE_TARGET_ == 0) {
            revert ErrInvalidTargets();
        }

        _twapUpdate();
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////

    function _resetTargetAndReserve() internal returns (uint256 baseBalance, uint256 quoteBalance) {
        baseBalance = _BASE_TOKEN_.balanceOf(address(this));
        quoteBalance = _QUOTE_TOKEN_.balanceOf(address(this));

        if (baseBalance > type(uint112).max || quoteBalance > type(uint112).max) {
            revert ErrOverflow();
        }

        _BASE_RESERVE_ = uint112(baseBalance);
        _QUOTE_RESERVE_ = uint112(quoteBalance);
        _BASE_TARGET_ = uint112(baseBalance);
        _QUOTE_TARGET_ = uint112(quoteBalance);
        _RState_ = uint32(PMMPricing.RState.ONE);

        _twapUpdate();
    }

    function _twapUpdate() internal {
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - _BLOCK_TIMESTAMP_LAST_;

        if (timeElapsed > 0 && _BASE_RESERVE_ != 0 && _QUOTE_RESERVE_ != 0) {
            /// @dev It is desired and expected for this value to
            /// overflow once it has hit the max of `type.uint256`.
            unchecked {
                _BASE_PRICE_CUMULATIVE_LAST_ += getMidPrice() * timeElapsed;
            }
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

    //////////////////////////////////////////////////////////////////////////////////////
    /// MODIFIERS
    //////////////////////////////////////////////////////////////////////////////////////

    modifier onlyImplementationOwner() {
        if (msg.sender != implementation.owner()) {
            revert ErrNotImplementationOwner();
        }
        _;
    }

    /// @dev owner is always considered an operator
    modifier onlyImplementationOperators() {
        if (!isImplementationOperator(msg.sender)) {
            revert ErrNotAllowedImplementationOperator();
        }
        _;
    }

    /// @dev can only be called on a clone contract
    modifier onlyClones() {
        if (address(this) == address(implementation)) {
            revert ErrNotClone();
        }
        _;
    }

    /// @dev can only be called on the implementation contract
    modifier onlyImplementation() {
        if (address(this) != address(implementation)) {
            revert ErrNotImplementation();
        }
        _;
    }

    modifier onlyProtocolOwnedPool() {
        if (!_PROTOCOL_OWNED_POOL_) {
            revert ErrNotAllowed();
        }
        _;
    }

    modifier whenPaused() {
        if (!_PAUSED_) {
            revert ErrNotPaused();
        }
        _;
    }

    /// @dev When it's a paused protocol owned pool,
    /// only the implementation operators can call the function
    /// A normal pool can never be paused.
    modifier whenNotPaused() {
        if (_PROTOCOL_OWNED_POOL_ && _PAUSED_ && !isImplementationOperator(msg.sender)) {
            revert ErrNotAllowedImplementationOperator();
        }
        _;
    }
}
