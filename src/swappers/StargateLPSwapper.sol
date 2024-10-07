// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {IStargatePool, IStargateRouter} from "/interfaces/IStargate.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";

/// @notice LP liquidation/deleverage swapper for Stargate LPs using Matcha/0x aggregator
contract StargateLPSwapper is ISwapperV2 {
    using SafeTransferLib for address;

    error ErrSwapFailed();

    IBentoBoxLite public immutable box;
    IStargatePool public immutable pool;
    address public immutable mim;
    address public immutable underlyingToken;
    IStargateRouter public immutable stargateRouter;
    uint16 public immutable poolId;

    constructor(IBentoBoxLite _box, IStargatePool _pool, uint16 _poolId, IStargateRouter _stargateRouter, address _mim) {
        box = _box;
        pool = _pool;
        poolId = _poolId;
        mim = _mim;
        stargateRouter = _stargateRouter;
        underlyingToken = _pool.token();
        mim.safeApprove(address(_box), type(uint256).max);
    }

    /// @inheritdoc ISwapperV2
    function swap(
        address,
        address,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) public override returns (uint256 extraShare, uint256 shareReturned) {
        (address to, bytes memory swapData) = abi.decode(data, (address, bytes));

        box.withdraw(address(pool), address(this), address(this), 0, shareFrom);

        // use the full balance so it's easier to check if everything has been redeemed.
        uint256 amount = IERC20(address(pool)).balanceOf(address(this));

        // Stargate Pool LP -> Underlying Token
        stargateRouter.instantRedeemLocal(poolId, amount, address(this));
        require(IERC20(address(pool)).balanceOf(address(this)) == 0, "Cannot fully redeem");

        if (IERC20(underlyingToken).allowance(address(this), to) != type(uint256).max) {
            underlyingToken.safeApprove(to, type(uint256).max);
        }

        // underlying -> MIM
        (bool success, ) = to.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        // Refund remaining underlying balance to the recipient
        underlyingToken.safeTransfer(recipient, underlyingToken.balanceOf(address(this)));

        (, shareReturned) = box.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
