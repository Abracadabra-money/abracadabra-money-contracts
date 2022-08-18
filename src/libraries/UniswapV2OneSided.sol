// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/IUniswapV2Pair.sol";
import "interfaces/IUniswapV2Router01.sol";
import "./Babylonian.sol";

library UniswapV2OneSided {
    using BoringERC20 for IERC20;

    struct AddLiquidityAndOneSideRemainingParams {
        IUniswapV2Router01 router;
        IUniswapV2Pair pair;
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 token0Amount;
        uint256 token1Amount;
        uint256 minOneSideableAmount0;
        uint256 minOneSideableAmount1;
        address recipient;
    }

    struct AddLiquidityFromSingleTokenParams {
        IUniswapV2Router01 router;
        IUniswapV2Pair pair;
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        address tokenIn;
        uint256 tokenInAmount;
        address recipient;
    }

    function _calculateSwapInAmount(uint256 reserveIn, uint256 userIn) internal pure returns (uint256) {
        return (Babylonian.sqrt(reserveIn * ((userIn * 3988000) + (reserveIn * 3988009))) - (reserveIn * 1997)) / 1994;
    }

    function _calculateSwapInAmountUsingCustomFees(
        uint256 reserveIn,
        uint256 amountIn,
        uint256 swapFeeBps
    ) internal pure returns (uint256) {
        uint256 caclulatedFeeA = 20000 - swapFeeBps;
        uint256 caclulatedFeeB = 10000 - swapFeeBps;
        uint256 caclulatedFeeC = 4 * caclulatedFeeB * 10000;

        return
            (Babylonian.sqrt((caclulatedFeeA * caclulatedFeeA) * (reserveIn * reserveIn) + (caclulatedFeeC * amountIn * reserveIn)) -
                caclulatedFeeA *
                reserveIn) / (2 * caclulatedFeeB);
    }

    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function addLiquidityAndOneSideRemaining(AddLiquidityAndOneSideRemainingParams memory params)
        internal
        returns (
            uint256 idealAmount0,
            uint256 idealAmount1,
            uint256 liquidity
        )
    {
        (idealAmount0, idealAmount1, liquidity) = params.router.addLiquidity(
            params.token0,
            params.token1,
            params.token0Amount,
            params.token1Amount,
            0,
            0,
            params.recipient,
            type(uint256).max
        );

        params.token0Amount -= idealAmount0;
        params.token1Amount -= idealAmount1;

        address oneSideTokenIn;
        uint256 oneSideTokenAmount;

        if (params.token0Amount >= params.minOneSideableAmount0) {
            oneSideTokenIn = params.token0;
            oneSideTokenAmount = params.token0Amount;
        } else if (params.token1Amount > params.minOneSideableAmount1) {
            oneSideTokenIn = params.token1;
            oneSideTokenAmount = params.token1Amount;
        }

        if (oneSideTokenAmount > 0) {
            AddLiquidityFromSingleTokenParams memory _addLiquidityFromSingleTokenParams = AddLiquidityFromSingleTokenParams(
                params.router,
                params.pair,
                params.token0,
                params.token1,
                params.reserve0,
                params.reserve1,
                oneSideTokenIn,
                oneSideTokenAmount,
                params.recipient
            );

            (uint256 _idealAmount0, uint256 _idealAmount1, uint256 _liquidity) = addLiquidityFromSingleToken(
                _addLiquidityFromSingleTokenParams
            );

            idealAmount0 += _idealAmount0;
            idealAmount1 += _idealAmount1;
            liquidity += _liquidity;
        }
    }

    function addLiquidityFromSingleToken(AddLiquidityFromSingleTokenParams memory params)
        internal
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        if (params.tokenIn == params.token0) {
            uint256 tokenInSwapAmount = _calculateSwapInAmount(params.reserve0, params.tokenInAmount);
            params.tokenInAmount -= tokenInSwapAmount;
            uint256 sideTokenAmount = _getAmountOut(tokenInSwapAmount, params.reserve0, params.reserve1);
            IERC20(params.tokenIn).safeTransfer(address(params.pair), tokenInSwapAmount);
            params.pair.swap(0, sideTokenAmount, address(this), "");
            return
                params.router.addLiquidity(
                    params.token0,
                    params.token1,
                    params.tokenInAmount,
                    sideTokenAmount,
                    0,
                    0,
                    params.recipient,
                    type(uint256).max
                );
        } else {
            uint256 tokenInSwapAmount = _calculateSwapInAmount(params.reserve1, params.tokenInAmount);
            params.tokenInAmount -= tokenInSwapAmount;
            uint256 sideTokenAmount = _getAmountOut(tokenInSwapAmount, params.reserve1, params.reserve0);
            IERC20(params.tokenIn).safeTransfer(address(params.pair), tokenInSwapAmount);
            params.pair.swap(sideTokenAmount, 0, address(this), "");

            return
                params.router.addLiquidity(
                    params.token0,
                    params.token1,
                    sideTokenAmount,
                    params.tokenInAmount,
                    0,
                    0,
                    params.recipient,
                    type(uint256).max
                );
        }
    }
}
