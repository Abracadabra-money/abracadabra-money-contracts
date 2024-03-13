// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {Math} from "/mimswap/libraries/Math.sol";
import {DecimalMath} from "/mimswap/libraries/DecimalMath.sol";
import {IWETH} from "interfaces/IWETH.sol";
import {IMagicLP} from "/mimswap/interfaces/IMagicLP.sol";
import {IFactory} from "/mimswap/interfaces/IFactory.sol";
import {IERC20Metadata} from "openzeppelin-contracts/interfaces/IERC20Metadata.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";

/// @notice Router for creating and interacting with MagicLP
/// Can only be used for pool created by the Factory
///
/// @dev A pool can be removed from the Factory. So, when integrating with this contract,
/// validate that the pool exists using the Factory `poolExists` function.
contract Router is ReentrancyGuard {
    using SafeTransferLib for address;
    using SafeTransferLib for address payable;

    error ErrNotETHLP();
    error ErrExpired();
    error ErrZeroAddress();
    error ErrPathTooLong();
    error ErrEmptyPath();
    error ErrBadPath();
    error ErrTooHighSlippage(uint256 amountOut);
    error ErrInvalidBaseToken();
    error ErrInvalidQuoteToken();
    error ErrInTokenNotETH();
    error ErrOutTokenNotETH();
    error ErrInvalidQuoteTarget();
    error ErrZeroDecimals();
    error ErrDecimalsDifferenceTooLarge();
    error ErrUnknownPool();

    uint256 public constant MAX_BASE_QUOTE_DECIMALS_DIFFERENCE = 12;

    IWETH public immutable weth;
    IFactory public immutable factory;

    receive() external payable {}

    constructor(IWETH weth_, IFactory factory_) {
        if (address(weth_) == address(0) || address(factory_) == address(0)) {
            revert ErrZeroAddress();
        }

        weth = weth_;
        factory = factory_;
    }

    modifier ensureDeadline(uint256 deadline) {
        if (block.timestamp > deadline) {
            revert ErrExpired();
        }
        _;
    }

    modifier onlyKnownPool(address pool) {
        if (!factory.poolExists(pool)) {
            revert ErrUnknownPool();
        }
        _;
    }

    function createPool(
        address baseToken,
        address quoteToken,
        uint256 lpFeeRate,
        uint256 i,
        uint256 k,
        address to,
        uint256 baseInAmount,
        uint256 quoteInAmount,
        bool protocolOwnedPool
    ) public virtual returns (address clone, uint256 shares) {
        _validateDecimals(IERC20Metadata(baseToken).decimals(), IERC20Metadata(quoteToken).decimals());

        clone = IFactory(factory).create(baseToken, quoteToken, lpFeeRate, i, k, protocolOwnedPool);

        baseToken.safeTransferFrom(msg.sender, clone, baseInAmount);
        quoteToken.safeTransferFrom(msg.sender, clone, quoteInAmount);
        (shares, , ) = IMagicLP(clone).buyShares(to);
    }

    function createPoolETH(
        address token,
        bool useTokenAsQuote,
        uint256 lpFeeRate,
        uint256 i,
        uint256 k,
        address to,
        uint256 tokenInAmount,
        bool protocolOwnedPool
    ) public payable virtual returns (address clone, uint256 shares) {
        if (useTokenAsQuote) {
            _validateDecimals(18, IERC20Metadata(token).decimals());
        } else {
            _validateDecimals(IERC20Metadata(token).decimals(), 18);
        }

        clone = IFactory(factory).create(
            useTokenAsQuote ? address(weth) : token,
            useTokenAsQuote ? token : address(weth),
            lpFeeRate,
            i,
            k,
            protocolOwnedPool
        );

        weth.deposit{value: msg.value}();
        token.safeTransferFrom(msg.sender, clone, tokenInAmount);
        address(weth).safeTransferFrom(address(this), clone, msg.value);
        (shares, , ) = IMagicLP(clone).buyShares(to);
    }

    function previewCreatePool(
        uint256 i,
        uint256 baseInAmount,
        uint256 quoteInAmount
    ) external pure returns (uint256 baseAdjustedInAmount, uint256 quoteAdjustedInAmount, uint256 shares) {
        shares = quoteInAmount < DecimalMath.mulFloor(baseInAmount, i) ? DecimalMath.divFloor(quoteInAmount, i) : baseInAmount;
        baseAdjustedInAmount = shares;
        quoteAdjustedInAmount = DecimalMath.mulFloor(shares, i);

        if (shares <= 2001) {
            return (0, 0, 0);
        }

        shares -= 1001;
    }

    function previewAddLiquidity(
        address lp,
        uint256 baseInAmount,
        uint256 quoteInAmount
    )
        external
        view
        nonReadReentrant
        onlyKnownPool(lp)
        returns (uint256 baseAdjustedInAmount, uint256 quoteAdjustedInAmount, uint256 shares)
    {
        (uint256 baseReserve, uint256 quoteReserve) = IMagicLP(lp).getReserves();

        uint256 baseBalance = IMagicLP(lp)._BASE_TOKEN_().balanceOf(address(lp)) + baseInAmount;
        uint256 quoteBalance = IMagicLP(lp)._QUOTE_TOKEN_().balanceOf(address(lp)) + quoteInAmount;

        baseInAmount = baseBalance - baseReserve;
        quoteInAmount = quoteBalance - quoteReserve;

        if (baseInAmount == 0) {
            return (0, 0, 0);
        }

        uint256 totalSupply = IERC20(lp).totalSupply();

        if (totalSupply == 0) {
            if (quoteBalance == 0) {
                return (0, 0, 0);
            }

            uint256 i = IMagicLP(lp)._I_();

            shares = quoteBalance < DecimalMath.mulFloor(baseBalance, i) ? DecimalMath.divFloor(quoteBalance, i) : baseBalance;
            baseAdjustedInAmount = shares;
            quoteAdjustedInAmount = DecimalMath.mulFloor(shares, i);

            if (shares <= 2001) {
                return (0, 0, 0);
            }

            shares -= 1001;
        } else if (baseReserve > 0 && quoteReserve > 0) {
            uint256 baseInputRatio = DecimalMath.divFloor(baseInAmount, baseReserve);
            uint256 quoteInputRatio = DecimalMath.divFloor(quoteInAmount, quoteReserve);
            if (baseInputRatio <= quoteInputRatio) {
                baseAdjustedInAmount = baseInAmount;
                quoteAdjustedInAmount = DecimalMath.mulCeil(quoteReserve, baseInputRatio);
                shares = DecimalMath.mulFloor(totalSupply, baseInputRatio);
            } else {
                quoteAdjustedInAmount = quoteInAmount;
                baseAdjustedInAmount = DecimalMath.mulCeil(baseReserve, quoteInputRatio);
                shares = DecimalMath.mulFloor(totalSupply, quoteInputRatio);
            }
        }
    }

    function addLiquidity(
        address lp,
        address to,
        uint256 baseInAmount,
        uint256 quoteInAmount,
        uint256 minimumShares,
        uint256 deadline
    )
        public
        virtual
        ensureDeadline(deadline)
        onlyKnownPool(lp)
        returns (uint256 baseAdjustedInAmount, uint256 quoteAdjustedInAmount, uint256 shares)
    {
        (baseAdjustedInAmount, quoteAdjustedInAmount) = _adjustAddLiquidity(lp, baseInAmount, quoteInAmount);

        IMagicLP(lp)._BASE_TOKEN_().safeTransferFrom(msg.sender, lp, baseAdjustedInAmount);
        IMagicLP(lp)._QUOTE_TOKEN_().safeTransferFrom(msg.sender, lp, quoteAdjustedInAmount);

        shares = _addLiquidity(lp, to, minimumShares);
    }

    function addLiquidityUnsafe(
        address lp,
        address to,
        uint256 baseInAmount,
        uint256 quoteInAmount,
        uint256 minimumShares,
        uint256 deadline
    ) public virtual ensureDeadline(deadline) onlyKnownPool(lp) returns (uint256 shares) {
        IMagicLP(lp)._BASE_TOKEN_().safeTransferFrom(msg.sender, lp, baseInAmount);
        IMagicLP(lp)._QUOTE_TOKEN_().safeTransferFrom(msg.sender, lp, quoteInAmount);

        return _addLiquidity(lp, to, minimumShares);
    }

    function addLiquidityETH(
        address lp,
        address to,
        address payable refundTo,
        uint256 tokenInAmount,
        uint256 minimumShares,
        uint256 deadline
    )
        public
        payable
        virtual
        nonReentrant
        ensureDeadline(deadline)
        onlyKnownPool(lp)
        returns (uint256 baseAdjustedInAmount, uint256 quoteAdjustedInAmount, uint256 shares)
    {
        uint256 wethAdjustedAmount;
        uint256 tokenAdjustedAmount;
        address token = IMagicLP(lp)._BASE_TOKEN_();
        if (token == address(weth)) {
            token = IMagicLP(lp)._QUOTE_TOKEN_();
            (baseAdjustedInAmount, quoteAdjustedInAmount) = _adjustAddLiquidity(lp, msg.value, tokenInAmount);
            wethAdjustedAmount = baseAdjustedInAmount;
            tokenAdjustedAmount = quoteAdjustedInAmount;
        } else if (IMagicLP(lp)._QUOTE_TOKEN_() == address(weth)) {
            (baseAdjustedInAmount, quoteAdjustedInAmount) = _adjustAddLiquidity(lp, tokenInAmount, msg.value);
            wethAdjustedAmount = quoteAdjustedInAmount;
            tokenAdjustedAmount = baseAdjustedInAmount;
        } else {
            revert ErrNotETHLP();
        }

        weth.deposit{value: wethAdjustedAmount}();
        address(weth).safeTransfer(lp, wethAdjustedAmount);

        // Refund unused ETH
        if (msg.value > wethAdjustedAmount) {
            refundTo.safeTransferETH(msg.value - wethAdjustedAmount);
        }

        token.safeTransferFrom(msg.sender, lp, tokenAdjustedAmount);

        shares = _addLiquidity(lp, to, minimumShares);
    }

    function addLiquidityETHUnsafe(
        address lp,
        address to,
        uint256 tokenInAmount,
        uint256 minimumShares,
        uint256 deadline
    ) public payable virtual ensureDeadline(deadline) onlyKnownPool(lp) returns (uint256 shares) {
        address token = IMagicLP(lp)._BASE_TOKEN_();
        if (token == address(weth)) {
            token = IMagicLP(lp)._QUOTE_TOKEN_();
        } else if (IMagicLP(lp)._QUOTE_TOKEN_() != address(weth)) {
            revert ErrNotETHLP();
        }

        weth.deposit{value: msg.value}();
        address(weth).safeTransfer(lp, msg.value);

        token.safeTransferFrom(msg.sender, lp, tokenInAmount);

        return _addLiquidity(lp, to, minimumShares);
    }

    function previewRemoveLiquidity(
        address lp,
        uint256 sharesIn
    ) external view nonReadReentrant onlyKnownPool(lp) returns (uint256 baseAmountOut, uint256 quoteAmountOut) {
        uint256 baseBalance = IMagicLP(lp)._BASE_TOKEN_().balanceOf(address(lp));
        uint256 quoteBalance = IMagicLP(lp)._QUOTE_TOKEN_().balanceOf(address(lp));

        uint256 totalShares = IERC20(lp).totalSupply();

        baseAmountOut = (baseBalance * sharesIn) / totalShares;
        quoteAmountOut = (quoteBalance * sharesIn) / totalShares;
    }

    function removeLiquidity(
        address lp,
        address to,
        uint256 sharesIn,
        uint256 minimumBaseAmount,
        uint256 minimumQuoteAmount,
        uint256 deadline
    ) public virtual onlyKnownPool(lp) returns (uint256 baseAmountOut, uint256 quoteAmountOut) {
        lp.safeTransferFrom(msg.sender, address(this), sharesIn);

        return IMagicLP(lp).sellShares(sharesIn, to, minimumBaseAmount, minimumQuoteAmount, "", deadline);
    }

    function removeLiquidityETH(
        address lp,
        address to,
        uint256 sharesIn,
        uint256 minimumETHAmount,
        uint256 minimumTokenAmount,
        uint256 deadline
    ) public virtual onlyKnownPool(lp) returns (uint256 ethAmountOut, uint256 tokenAmountOut) {
        lp.safeTransferFrom(msg.sender, address(this), sharesIn);

        address token = IMagicLP(lp)._BASE_TOKEN_();
        if (token == address(weth)) {
            token = IMagicLP(lp)._QUOTE_TOKEN_();
            (ethAmountOut, tokenAmountOut) = IMagicLP(lp).sellShares(
                sharesIn,
                address(this),
                minimumETHAmount,
                minimumTokenAmount,
                "",
                deadline
            );
        } else if (IMagicLP(lp)._QUOTE_TOKEN_() == address(weth)) {
            (tokenAmountOut, ethAmountOut) = IMagicLP(lp).sellShares(
                sharesIn,
                address(this),
                minimumTokenAmount,
                minimumETHAmount,
                "",
                deadline
            );
        } else {
            revert ErrNotETHLP();
        }

        weth.withdraw(ethAmountOut);
        to.safeTransferETH(ethAmountOut);

        token.safeTransfer(to, tokenAmountOut);
    }

    function swapTokensForTokens(
        address to,
        uint256 amountIn,
        address[] calldata path,
        uint256 directions,
        uint256 minimumOut,
        uint256 deadline
    ) public virtual ensureDeadline(deadline) returns (uint256 amountOut) {
        _validatePath(path);

        address firstLp = path[0];

        // Transfer to the first LP
        if (directions & 1 == 0) {
            IMagicLP(firstLp)._BASE_TOKEN_().safeTransferFrom(msg.sender, address(firstLp), amountIn);
        } else {
            IMagicLP(firstLp)._QUOTE_TOKEN_().safeTransferFrom(msg.sender, address(firstLp), amountIn);
        }

        return _swap(to, path, directions, minimumOut);
    }

    function swapETHForTokens(
        address to,
        address[] calldata path,
        uint256 directions,
        uint256 minimumOut,
        uint256 deadline
    ) public payable virtual ensureDeadline(deadline) returns (uint256 amountOut) {
        _validatePath(path);

        address firstLp = path[0];
        address inToken;

        if (directions & 1 == 0) {
            inToken = IMagicLP(firstLp)._BASE_TOKEN_();
        } else {
            inToken = IMagicLP(firstLp)._QUOTE_TOKEN_();
        }

        // Transfer to the first LP
        if (inToken != address(weth)) {
            revert ErrInTokenNotETH();
        }

        weth.deposit{value: msg.value}();
        inToken.safeTransfer(address(firstLp), msg.value);

        return _swap(to, path, directions, minimumOut);
    }

    function swapTokensForETH(
        address to,
        uint256 amountIn,
        address[] calldata path,
        uint256 directions,
        uint256 minimumOut,
        uint256 deadline
    ) public virtual ensureDeadline(deadline) returns (uint256 amountOut) {
        _validatePath(path);

        uint256 lastLpIndex = path.length - 1;
        address lastLp = path[lastLpIndex];
        address outToken;

        if ((directions >> lastLpIndex) & 1 == 0) {
            outToken = IMagicLP(lastLp)._QUOTE_TOKEN_();
        } else {
            outToken = IMagicLP(lastLp)._BASE_TOKEN_();
        }

        if (outToken != address(weth)) {
            revert ErrOutTokenNotETH();
        }

        address firstLp = path[0];

        // Transfer to the first LP
        if (directions & 1 == 0) {
            IMagicLP(firstLp)._BASE_TOKEN_().safeTransferFrom(msg.sender, firstLp, amountIn);
        } else {
            IMagicLP(firstLp)._QUOTE_TOKEN_().safeTransferFrom(msg.sender, firstLp, amountIn);
        }

        amountOut = _swap(address(this), path, directions, minimumOut);
        weth.withdraw(amountOut);

        to.safeTransferETH(amountOut);
    }

    function sellBaseTokensForTokens(
        address lp,
        address to,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) public virtual ensureDeadline(deadline) onlyKnownPool(lp) returns (uint256 amountOut) {
        IMagicLP(lp)._BASE_TOKEN_().safeTransferFrom(msg.sender, lp, amountIn);
        return _sellBase(lp, to, minimumOut);
    }

    function sellBaseETHForTokens(
        address lp,
        address to,
        uint256 minimumOut,
        uint256 deadline
    ) public payable virtual ensureDeadline(deadline) onlyKnownPool(lp) returns (uint256 amountOut) {
        address baseToken = IMagicLP(lp)._BASE_TOKEN_();

        if (baseToken != address(weth)) {
            revert ErrInvalidBaseToken();
        }

        weth.deposit{value: msg.value}();
        baseToken.safeTransfer(lp, msg.value);
        return _sellBase(lp, to, minimumOut);
    }

    function sellBaseTokensForETH(
        address lp,
        address to,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) public virtual ensureDeadline(deadline) onlyKnownPool(lp) returns (uint256 amountOut) {
        if (IMagicLP(lp)._QUOTE_TOKEN_() != address(weth)) {
            revert ErrInvalidQuoteToken();
        }

        IMagicLP(lp)._BASE_TOKEN_().safeTransferFrom(msg.sender, lp, amountIn);
        amountOut = _sellBase(lp, address(this), minimumOut);
        weth.withdraw(amountOut);
        to.safeTransferETH(amountOut);
    }

    function sellQuoteTokensForTokens(
        address lp,
        address to,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) public virtual ensureDeadline(deadline) onlyKnownPool(lp) returns (uint256 amountOut) {
        IMagicLP(lp)._QUOTE_TOKEN_().safeTransferFrom(msg.sender, lp, amountIn);

        return _sellQuote(lp, to, minimumOut);
    }

    function sellQuoteETHForTokens(
        address lp,
        address to,
        uint256 minimumOut,
        uint256 deadline
    ) public payable virtual ensureDeadline(deadline) onlyKnownPool(lp) returns (uint256 amountOut) {
        address quoteToken = IMagicLP(lp)._QUOTE_TOKEN_();

        if (quoteToken != address(weth)) {
            revert ErrInvalidQuoteToken();
        }

        weth.deposit{value: msg.value}();
        quoteToken.safeTransfer(lp, msg.value);
        return _sellQuote(lp, to, minimumOut);
    }

    function sellQuoteTokensForETH(
        address lp,
        address to,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) public virtual ensureDeadline(deadline) onlyKnownPool(lp) returns (uint256 amountOut) {
        if (IMagicLP(lp)._BASE_TOKEN_() != address(weth)) {
            revert ErrInvalidBaseToken();
        }

        IMagicLP(lp)._QUOTE_TOKEN_().safeTransferFrom(msg.sender, lp, amountIn);
        amountOut = _sellQuote(lp, address(this), minimumOut);
        weth.withdraw(amountOut);
        to.safeTransferETH(amountOut);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////

    function _addLiquidity(address lp, address to, uint256 minimumShares) internal returns (uint256 shares) {
        (shares, , ) = IMagicLP(lp).buyShares(to);

        if (shares < minimumShares) {
            revert ErrTooHighSlippage(shares);
        }
    }

    /// Adapted from: https://github.com/DODOEX/contractV2/blob/main/contracts/SmartRoute/proxies/DODODspProxy.sol
    /// Copyright 2020 DODO ZOO. Licensed under Apache-2.0.
    function _adjustAddLiquidity(
        address lp,
        uint256 baseInAmount,
        uint256 quoteInAmount
    ) internal view returns (uint256 baseAdjustedInAmount, uint256 quoteAdjustedInAmount) {
        (uint256 baseReserve, uint256 quoteReserve) = IMagicLP(lp).getReserves();
        uint256 baseBalance = IMagicLP(lp)._BASE_TOKEN_().balanceOf(address(lp)) + baseInAmount;
        uint256 quoteBalance = IMagicLP(lp)._QUOTE_TOKEN_().balanceOf(address(lp)) + quoteInAmount;

        baseInAmount = baseBalance - baseReserve;
        quoteInAmount = quoteBalance - quoteReserve;

        if (IERC20(lp).totalSupply() == 0) {
            uint256 i = IMagicLP(lp)._I_();
            uint256 shares = quoteInAmount < DecimalMath.mulFloor(baseInAmount, i) ? DecimalMath.divFloor(quoteInAmount, i) : baseInAmount;
            baseAdjustedInAmount = shares;
            quoteAdjustedInAmount = DecimalMath.mulFloor(shares, i);
        } else {
            if (quoteReserve > 0 && baseReserve > 0) {
                uint256 baseIncreaseRatio = DecimalMath.divFloor(baseInAmount, baseReserve);
                uint256 quoteIncreaseRatio = DecimalMath.divFloor(quoteInAmount, quoteReserve);
                if (baseIncreaseRatio <= quoteIncreaseRatio) {
                    baseAdjustedInAmount = baseInAmount;
                    quoteAdjustedInAmount = DecimalMath.mulFloor(quoteReserve, baseIncreaseRatio);
                } else {
                    quoteAdjustedInAmount = quoteInAmount;
                    baseAdjustedInAmount = DecimalMath.mulFloor(baseReserve, quoteIncreaseRatio);
                }
            }
        }
    }

    function _swap(address to, address[] calldata path, uint256 directions, uint256 minimumOut) internal returns (uint256 amountOut) {
        uint256 iterations = path.length - 1; // Subtract by one as last swap is done separately

        for (uint256 i = 0; i < iterations; ) {
            address lp = path[i];
            if (!factory.poolExists(lp)) {
                revert ErrUnknownPool();
            }

            if (directions & 1 == 0) {
                // Sell base
                IMagicLP(lp).sellBase(address(path[i + 1]));
            } else {
                // Sell quote
                IMagicLP(lp).sellQuote(address(path[i + 1]));
            }

            directions >>= 1;

            unchecked {
                ++i;
            }
        }

        if ((directions & 1 == 0)) {
            amountOut = IMagicLP(path[iterations]).sellBase(to);
        } else {
            amountOut = IMagicLP(path[iterations]).sellQuote(to);
        }

        if (amountOut < minimumOut) {
            revert ErrTooHighSlippage(amountOut);
        }
    }

    function _sellBase(address lp, address to, uint256 minimumOut) internal returns (uint256 amountOut) {
        amountOut = IMagicLP(lp).sellBase(to);
        if (amountOut < minimumOut) {
            revert ErrTooHighSlippage(amountOut);
        }
    }

    function _sellQuote(address lp, address to, uint256 minimumOut) internal returns (uint256 amountOut) {
        amountOut = IMagicLP(lp).sellQuote(to);

        if (amountOut < minimumOut) {
            revert ErrTooHighSlippage(amountOut);
        }
    }

    function _validatePath(address[] calldata path) internal pure {
        uint256 pathLength = path.length;

        // Max 256 because of bits in directions
        if (pathLength > 256) {
            revert ErrPathTooLong();
        }
        if (pathLength <= 0) {
            revert ErrEmptyPath();
        }
    }

    function _validateDecimals(uint8 baseDecimals, uint8 quoteDecimals) internal pure {
        if (baseDecimals == 0 || quoteDecimals == 0) {
            revert ErrZeroDecimals();
        }

        uint256 deltaDecimals = baseDecimals > quoteDecimals ? baseDecimals - quoteDecimals : quoteDecimals - baseDecimals;

        if (deltaDecimals > MAX_BASE_QUOTE_DECIMALS_DIFFERENCE) {
            revert ErrDecimalsDifferenceTooLarge();
        }
    }
}
