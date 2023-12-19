// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import {IUniswapV2Pair, IUniswapV2Router01} from "interfaces/IUniswapV2.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {BabylonianLib} from "./BabylonianLib.sol";

/* 
The following library is modified from @sushiswap/core/contracts/uniswapv2/libraries/UniswapV2Library.sol

changes: 
    - remove SafeMathUniswap library and replace all usage of it with basic operations
    - change casting from uint to bytes20 in pair address calculation and shift by 96 bits before casting
 */
library UniswapV2Library {
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "UniswapV2Library: ZERO_ADDRESS");
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB, bytes32 pairCodeHash) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);

        // Since Solidity 0.8.0 explicit conversions from literals larger than type(uint160).max to address are disallowed.
        // https://docs.soliditylang.org/en/develop/080-breaking-changes.html#new-restrictions
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            pairCodeHash // init code hash
                        )
                    )
                )
            )
        );
    }

    // fetches and sorts the reserves for a pair
    function getReserves(
        address factory,
        address tokenA,
        address tokenB,
        bytes32 pairCodeHash
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0, ) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB, pairCodeHash)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB) {
        require(amountA > 0, "UniswapV2Library: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(
        address factory,
        uint256 amountIn,
        address[] memory path,
        bytes32 pairCodeHash
    ) internal view returns (uint256[] memory amounts) {
        require(path.length >= 2, "UniswapV2Library: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(factory, path[i], path[i + 1], pairCodeHash);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(
        address factory,
        uint256 amountOut,
        address[] memory path,
        bytes32 pairCodeHash
    ) internal view returns (uint256[] memory amounts) {
        require(path.length >= 2, "UniswapV2Library: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(factory, path[i - 1], path[i], pairCodeHash);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}

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
        return (BabylonianLib.sqrt(reserveIn * ((userIn * 3988000) + (reserveIn * 3988009))) - (reserveIn * 1997)) / 1994;
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
            (BabylonianLib.sqrt((caclulatedFeeA * caclulatedFeeA) * (reserveIn * reserveIn) + (caclulatedFeeC * amountIn * reserveIn)) -
                caclulatedFeeA *
                reserveIn) / (2 * caclulatedFeeB);
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function addLiquidityAndOneSideRemaining(
        AddLiquidityAndOneSideRemainingParams memory params
    ) internal returns (uint256 idealAmount0, uint256 idealAmount1, uint256 liquidity) {
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

    function addLiquidityFromSingleToken(
        AddLiquidityFromSingleTokenParams memory params
    ) internal returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
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
