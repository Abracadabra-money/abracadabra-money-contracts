// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {IStargatePool, IStargateRouter} from "/interfaces/IStargate.sol";

/// @notice LP leverage swapper for Stargate LP using Matcha/0x aggregator
contract StargateLPLevSwapper is ILevSwapperV2 {
    using SafeTransferLib for address;

    error ErrSwapFailed();

    IBentoBoxLite public immutable box;
    IStargatePool public immutable pool;
    address public immutable mim;
    address public immutable underlyingToken;
    IStargateRouter public immutable stargateRouter;
    uint256 public immutable poolId;

    constructor(IBentoBoxLite _box, IStargatePool _pool, uint256 _poolId, IStargateRouter _stargateRouter, address _mim) {
        box = _box;
        pool = _pool;
        poolId = _poolId;
        mim = _mim;
        stargateRouter = _stargateRouter;
        address _underlyingToken = _pool.token();
        underlyingToken = _underlyingToken;

        _underlyingToken.safeApprove(address(_stargateRouter), type(uint256).max);
        _pool.approve(address(_box), type(uint256).max);
    }

    /// @inheritdoc ILevSwapperV2
    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        (address to, bytes memory swapData) = abi.decode(data, (address, bytes));

        box.withdraw(mim, address(this), address(this), 0, shareFrom);

        if (IERC20(mim).allowance(address(this), to) != type(uint256).max) {
            mim.safeApprove(to, type(uint256).max);
        }

        // MIM -> underlyingToken
        (bool success, ) = to.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        // Underlying Token -> Stargate Pool LP
        stargateRouter.addLiquidity(poolId, underlyingToken.balanceOf(address(this)), address(this));
        uint256 amount = pool.balanceOf(address(this));

        (, shareReturned) = box.deposit(address(pool), address(this), recipient, amount, 0);
        extraShare = shareReturned - shareToMin;
    }
}
