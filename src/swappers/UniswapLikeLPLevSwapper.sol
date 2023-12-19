// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {IUniswapV2Pair, IUniswapV2Router01} from "interfaces/IUniswapV2.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {ILevSwapperV2} from "interfaces/ILevSwapperV2.sol";
import {UniswapV2OneSided} from "libraries/UniswapV2Lib.sol";

/// @notice Generic LP leverage swapper for Uniswap like compatible DEX using Matcha/0x aggregator
contract UniswapLikeLPLevSwapper is ILevSwapperV2 {
    using BoringERC20 for IERC20;

    error ErrToken0SwapFailed();
    error ErrToken1SwapFailed();

    IBentoBoxV1 public immutable bentoBox;
    IUniswapV2Pair public immutable pair;
    IUniswapV2Router01 public immutable router;
    IERC20 public immutable mim;
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    address public immutable zeroXExchangeProxy;

    constructor(IBentoBoxV1 _bentoBox, IUniswapV2Router01 _router, IUniswapV2Pair _pair, IERC20 _mim, address _zeroXExchangeProxy) {
        bentoBox = _bentoBox;
        router = _router;
        pair = _pair;
        mim = _mim;
        zeroXExchangeProxy = _zeroXExchangeProxy;

        IERC20 _token0 = IERC20(_pair.token0());
        IERC20 _token1 = IERC20(_pair.token1());
        token0 = _token0;
        token1 = _token1;

        _token0.approve(address(_router), type(uint256).max);
        _token1.approve(address(_router), type(uint256).max);
        _mim.approve(_zeroXExchangeProxy, type(uint256).max);
    }

    /// @inheritdoc ILevSwapperV2
    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        // 0: MIM -> token0
        // 1: MIM -> token1
        (bytes[] memory swapData, uint256 minOneSideableAmount0, uint256 minOneSideableAmount1) = abi.decode(
            data,
            (bytes[], uint256, uint256)
        );

        bentoBox.withdraw(mim, address(this), address(this), 0, shareFrom);

        // MIM -> token0
        (bool success, ) = zeroXExchangeProxy.call(swapData[0]);
        if (!success) {
            revert ErrToken0SwapFailed();
        }

        // MIM -> token1
        (success, ) = zeroXExchangeProxy.call(swapData[1]);
        if (!success) {
            revert ErrToken1SwapFailed();
        }

        uint256 liquidity;

        {
            (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();

            UniswapV2OneSided.AddLiquidityAndOneSideRemainingParams memory params = UniswapV2OneSided.AddLiquidityAndOneSideRemainingParams(
                router,
                pair,
                address(token0),
                address(token1),
                reserve0,
                reserve1,
                token0.balanceOf(address(this)),
                token1.balanceOf(address(this)),
                minOneSideableAmount0,
                minOneSideableAmount1,
                address(bentoBox)
            );

            (, , liquidity) = UniswapV2OneSided.addLiquidityAndOneSideRemaining(params);
        }

        (, shareReturned) = bentoBox.deposit(IERC20(address(pair)), address(bentoBox), recipient, liquidity, 0);
        extraShare = shareReturned - shareToMin;
    }
}
