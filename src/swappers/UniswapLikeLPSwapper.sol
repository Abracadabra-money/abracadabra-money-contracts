// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IUniswapV2Pair} from "/interfaces/IUniswapV2.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";

/// @notice Generic LP liquidation/deleverage swapper for Uniswap like compatible DEX using Matcha/0x aggregator
contract UniswapLikeLPSwapper is ISwapperV2 {
    using SafeTransferLib for address;

    error ErrToken0SwapFailed();
    error ErrToken1SwapFailed();

    IBentoBoxLite public immutable box;
    IUniswapV2Pair public immutable pair;
    address public immutable mim;

    constructor(IBentoBoxLite _box, IUniswapV2Pair _pair, address _mim) {
        box = _box;
        pair = _pair;
        mim = _mim;

        mim.safeApprove(address(_box), type(uint256).max);
    }

    /// @inheritdoc ISwapperV2
    function swap(
        address /* token */,
        address /* mim */,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) public override returns (uint256 extraShare, uint256 shareReturned) {
        // 0: token0 -> MIM
        // 1: token1 -> MIM
        (address[] memory to, bytes[] memory swapData) = abi.decode(data, (address[], bytes[]));

        (uint256 amountFrom, ) = box.withdraw(address(pair), address(this), address(this), 0, shareFrom);

        pair.transfer(address(pair), amountFrom);
        pair.burn(address(this));

        if (IERC20(pair.token0()).allowance(address(this), to[0]) != type(uint256).max) {
            pair.token0().safeApprove(to[0], type(uint256).max);
        }

        if (IERC20(pair.token1()).allowance(address(this), to[1]) != type(uint256).max) {
            pair.token1().safeApprove(to[1], type(uint256).max);
        }

        // token0 -> MIM
        (bool success, ) = to[0].call(swapData[0]);
        if (!success) {
            revert ErrToken0SwapFailed();
        }

        // token1 -> MIM
        (success, ) = to[1].call(swapData[1]);
        if (!success) {
            revert ErrToken1SwapFailed();
        }

        (, shareReturned) = box.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
