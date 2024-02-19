// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {DecimalMath} from "/mimswap/libraries/DecimalMath.sol";
import {IWETH} from "interfaces/IWETH.sol";
import {IMagicLP} from "/mimswap/interfaces/IMagicLP.sol";

contract Router {
    using SafeTransferLib for address;
    using SafeTransferLib for address payable;

    error ErrBaseTokenNotETH();
    error ErrQuoteTokenNotETH();
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

    IWETH public immutable weth;

    receive() external payable {}

    constructor(IWETH weth_) {
        if (address(weth_) == address(0)) {
            revert ErrZeroAddress();
        }

        weth = weth_;
    }

    modifier ensureDeadline(uint256 deadline) {
        if (block.timestamp > deadline) {
            revert ErrExpired();
        }
        _;
    }

    function addLiquidity(
        address lp,
        address to,
        uint256 baseInAmount,
        uint256 quoteInAmount,
        uint256 minimumShares,
        uint256 deadline
    ) external ensureDeadline(deadline) returns (uint256 baseAdjustedInAmount, uint256 quoteAdjustedInAmount, uint256 shares) {
        (baseAdjustedInAmount, quoteAdjustedInAmount) = _adjustAddLiquidity(lp, baseInAmount, quoteInAmount);

        IMagicLP(lp)._BASE_TOKEN_().safeTransferFrom(msg.sender, lp, baseAdjustedInAmount);
        IMagicLP(lp)._QUOTE_TOKEN_().safeTransferFrom(msg.sender, lp, quoteAdjustedInAmount);

        shares = _addLiquidity(lp, to, minimumShares);
    }

    function addLiquidityBaseETH(
        address lp,
        address to,
        address payable refundTo,
        uint256 quoteInAmount,
        uint256 minimumShares,
        uint256 deadline
    ) external payable ensureDeadline(deadline) returns (uint256 baseAdjustedInAmount, uint256 quoteAdjustedInAmount, uint256 shares) {
        if (IMagicLP(lp)._BASE_TOKEN_() != address(weth)) {
            revert ErrBaseTokenNotETH();
        }

        (baseAdjustedInAmount, quoteAdjustedInAmount) = _adjustAddLiquidity(lp, msg.value, quoteInAmount);

        weth.deposit{value: baseAdjustedInAmount}();
        address(weth).safeTransfer(lp, baseAdjustedInAmount);

        // Refund unused ETH
        if (msg.value > baseAdjustedInAmount) {
            refundTo.safeTransferETH(msg.value - baseAdjustedInAmount);
        }

        IMagicLP(lp)._QUOTE_TOKEN_().safeTransferFrom(msg.sender, lp, quoteAdjustedInAmount);

        shares = _addLiquidity(lp, to, minimumShares);
    }

    function addLiquidityQuoteETH(
        address lp,
        address to,
        address payable refundTo,
        uint256 baseInAmount,
        uint256 minimumShares,
        uint256 deadline
    ) external payable ensureDeadline(deadline) returns (uint256 baseAdjustedInAmount, uint256 quoteAdjustedInAmount, uint256 shares) {
        if (IMagicLP(lp)._QUOTE_TOKEN_() != address(weth)) {
            revert ErrQuoteTokenNotETH();
        }

        (baseAdjustedInAmount, quoteAdjustedInAmount) = _adjustAddLiquidity(lp, baseInAmount, msg.value);

        weth.deposit{value: quoteAdjustedInAmount}();
        address(weth).safeTransfer(lp, quoteAdjustedInAmount);

        // Refund unused ETH
        if (msg.value > quoteAdjustedInAmount) {
            refundTo.safeTransferETH(msg.value - quoteAdjustedInAmount);
        }

        IMagicLP(lp)._BASE_TOKEN_().safeTransferFrom(msg.sender, lp, baseAdjustedInAmount);

        shares = _addLiquidity(lp, to, minimumShares);
    }

    function swapTokensForTokens(
        address to,
        uint256 amountIn,
        address[] calldata path,
        uint256 directions,
        uint256 minimumOut,
        uint256 deadline
    ) external ensureDeadline(deadline) returns (uint256 amountOut) {
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
    ) external payable ensureDeadline(deadline) returns (uint256 amountOut) {
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
    ) external payable ensureDeadline(deadline) returns (uint256 amountOut) {
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
    ) external ensureDeadline(deadline) returns (uint256 amountOut) {
        IMagicLP(lp)._BASE_TOKEN_().safeTransferFrom(msg.sender, lp, amountIn);
        return _sellBase(lp, to, minimumOut);
    }

    function sellBaseETHForTokens(
        address lp,
        address to,
        uint256 minimumOut,
        uint256 deadline
    ) external payable ensureDeadline(deadline) returns (uint256 amountOut) {
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
    ) external ensureDeadline(deadline) returns (uint256 amountOut) {
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
    ) external ensureDeadline(deadline) returns (uint256 amountOut) {
        IMagicLP(lp)._QUOTE_TOKEN_().safeTransferFrom(msg.sender, lp, amountIn);

        return _sellQuote(lp, to, minimumOut);
    }

    function sellQuoteETHForTokens(
        address lp,
        address to,
        uint256 minimumOut,
        uint256 deadline
    ) external payable ensureDeadline(deadline) returns (uint256 amountOut) {
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
    ) external ensureDeadline(deadline) returns (uint256 amountOut) {
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
        (uint256 baseReserve, uint256 quoteReserve) = IMagicLP(lp).getVaultReserve();
        if (quoteReserve == 0 && baseReserve == 0) {
            uint256 i = IMagicLP(lp)._I_();
            uint256 shares = quoteInAmount < DecimalMath.mulFloor(baseInAmount, i) ? DecimalMath.divFloor(quoteInAmount, i) : baseInAmount;
            baseAdjustedInAmount = shares;
            quoteAdjustedInAmount = DecimalMath.mulFloor(shares, i);
        }
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

    function _swap(address to, address[] calldata path, uint256 directions, uint256 minimumOut) internal returns (uint256 amountOut) {
        uint256 iterations = path.length - 1; // Subtract by one as last swap is done separately

        for (uint256 i = 0; i < iterations; ) {
            if (directions & 1 == 0) {
                // Sell base
                IMagicLP(path[i]).sellBase(address(path[i + 1]));
            } else {
                // Sell quote
                IMagicLP(path[i]).sellQuote(address(path[i + 1]));
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
}
