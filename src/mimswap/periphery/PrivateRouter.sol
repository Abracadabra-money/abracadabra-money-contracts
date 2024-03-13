// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Router} from "/mimswap/periphery/Router.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";
import {IFactory} from "/mimswap/interfaces/IFactory.sol";
import {IWETH} from "interfaces/IWETH.sol";

/// @notice Same as Router, but with an OperatableV2 modifier
/// so it can be whitelisted as an authorized protocol owned pool
/// MagicLP operator
contract PrivateRouter is Router, OperatableV2 {
    constructor(IWETH weth_, IFactory factory_, address owner_) Router(weth_, factory_) OperatableV2(owner_) {}

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
    ) public override onlyOperators returns (address clone, uint256 shares) {
        return super.createPool(baseToken, quoteToken, lpFeeRate, i, k, to, baseInAmount, quoteInAmount, protocolOwnedPool);
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
    ) public payable override onlyOperators returns (address clone, uint256 shares) {
        return super.createPoolETH(token, useTokenAsQuote, lpFeeRate, i, k, to, tokenInAmount, protocolOwnedPool);
    }

    function addLiquidity(
        address lp,
        address to,
        uint256 baseInAmount,
        uint256 quoteInAmount,
        uint256 minimumShares,
        uint256 deadline
    ) public override onlyOperators returns (uint256 baseAdjustedInAmount, uint256 quoteAdjustedInAmount, uint256 shares) {
        return super.addLiquidity(lp, to, baseInAmount, quoteInAmount, minimumShares, deadline);
    }

    function addLiquidityUnsafe(
        address lp,
        address to,
        uint256 baseInAmount,
        uint256 quoteInAmount,
        uint256 minimumShares,
        uint256 deadline
    ) public override onlyOperators returns (uint256 shares) {
        return super.addLiquidityUnsafe(lp, to, baseInAmount, quoteInAmount, minimumShares, deadline);
    }

    function addLiquidityETH(
        address lp,
        address to,
        address payable refundTo,
        uint256 tokenInAmount,
        uint256 minimumShares,
        uint256 deadline
    ) public payable override onlyOperators returns (uint256 baseAdjustedInAmount, uint256 quoteAdjustedInAmount, uint256 shares) {
        return super.addLiquidityETH(lp, to, refundTo, tokenInAmount, minimumShares, deadline);
    }

    function addLiquidityETHUnsafe(
        address lp,
        address to,
        uint256 tokenInAmount,
        uint256 minimumShares,
        uint256 deadline
    ) public payable override onlyOperators returns (uint256 shares) {
        return super.addLiquidityETHUnsafe(lp, to, tokenInAmount, minimumShares, deadline);
    }

    function removeLiquidity(
        address lp,
        address to,
        uint256 sharesIn,
        uint256 minimumBaseAmount,
        uint256 minimumQuoteAmount,
        uint256 deadline
    ) public override onlyOperators returns (uint256 baseAmountOut, uint256 quoteAmountOut) {
        return super.removeLiquidity(lp, to, sharesIn, minimumBaseAmount, minimumQuoteAmount, deadline);
    }

    function removeLiquidityETH(
        address lp,
        address to,
        uint256 sharesIn,
        uint256 minimumETHAmount,
        uint256 minimumTokenAmount,
        uint256 deadline
    ) public override onlyOperators returns (uint256 ethAmountOut, uint256 tokenAmountOut) {
        return super.removeLiquidityETH(lp, to, sharesIn, minimumETHAmount, minimumTokenAmount, deadline);
    }

    function swapTokensForTokens(
        address to,
        uint256 amountIn,
        address[] calldata path,
        uint256 directions,
        uint256 minimumOut,
        uint256 deadline
    ) public override onlyOperators returns (uint256 amountOut) {
        return super.swapTokensForTokens(to, amountIn, path, directions, minimumOut, deadline);
    }

    function swapETHForTokens(
        address to,
        address[] calldata path,
        uint256 directions,
        uint256 minimumOut,
        uint256 deadline
    ) public payable override onlyOperators returns (uint256 amountOut) {
        return super.swapETHForTokens(to, path, directions, minimumOut, deadline);
    }

    function swapTokensForETH(
        address to,
        uint256 amountIn,
        address[] calldata path,
        uint256 directions,
        uint256 minimumOut,
        uint256 deadline
    ) public override onlyOperators returns (uint256 amountOut) {
        return super.swapTokensForETH(to, amountIn, path, directions, minimumOut, deadline);
    }

    function sellBaseTokensForTokens(
        address lp,
        address to,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) public override onlyOperators returns (uint256 amountOut) {
        return super.sellBaseTokensForTokens(lp, to, amountIn, minimumOut, deadline);
    }

    function sellBaseETHForTokens(
        address lp,
        address to,
        uint256 minimumOut,
        uint256 deadline
    ) public payable override onlyOperators returns (uint256 amountOut) {
        return super.sellBaseETHForTokens(lp, to, minimumOut, deadline);
    }

    function sellBaseTokensForETH(
        address lp,
        address to,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) public override onlyOperators returns (uint256 amountOut) {
        return super.sellBaseTokensForETH(lp, to, amountIn, minimumOut, deadline);
    }

    function sellQuoteTokensForTokens(
        address lp,
        address to,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) public override onlyOperators returns (uint256 amountOut) {
        return super.sellQuoteTokensForTokens(lp, to, amountIn, minimumOut, deadline);
    }

    function sellQuoteETHForTokens(
        address lp,
        address to,
        uint256 minimumOut,
        uint256 deadline
    ) public payable override onlyOperators returns (uint256 amountOut) {
        return super.sellQuoteETHForTokens(lp, to, minimumOut, deadline);
    }

    function sellQuoteTokensForETH(
        address lp,
        address to,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline
    ) public override onlyOperators returns (uint256 amountOut) {
        return super.sellQuoteTokensForETH(lp, to, amountIn, minimumOut, deadline);
    }
}
