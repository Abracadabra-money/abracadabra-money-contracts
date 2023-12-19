// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {IUniswapV2Pair} from "interfaces/IUniswapV2.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {ISwapperV2} from "interfaces/ISwapperV2.sol";
import {IStargatePool, IStargateRouter} from "interfaces/IStargate.sol";
import {SafeApproveLib} from "libraries/SafeApproveLib.sol";

/// @notice LP liquidation/deleverage swapper for Stargate LPs using Matcha/0x aggregator
contract StargateLPSwapper is ISwapperV2 {
    using BoringERC20 for IERC20;
    using SafeApproveLib for IERC20;

    error ErrSwapFailed();

    IBentoBoxV1 public immutable bentoBox;
    IStargatePool public immutable pool;
    IERC20 public immutable mim;
    IERC20 public immutable underlyingToken;
    IStargateRouter public immutable stargateRouter;
    address public immutable zeroXExchangeProxy;
    uint16 public immutable poolId;

    constructor(
        IBentoBoxV1 _bentoBox,
        IStargatePool _pool,
        uint16 _poolId,
        IStargateRouter _stargateRouter,
        IERC20 _mim,
        address _zeroXExchangeProxy
    ) {
        bentoBox = _bentoBox;
        pool = _pool;
        poolId = _poolId;
        mim = _mim;
        stargateRouter = _stargateRouter;
        zeroXExchangeProxy = _zeroXExchangeProxy;
        underlyingToken = IERC20(_pool.token());

        underlyingToken.safeApprove(_zeroXExchangeProxy, type(uint256).max);
        mim.approve(address(_bentoBox), type(uint256).max);
    }

    /// @inheritdoc ISwapperV2
    function swap(
        address,
        address,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata swapData
    ) public override returns (uint256 extraShare, uint256 shareReturned) {
        bentoBox.withdraw(IERC20(address(pool)), address(this), address(this), 0, shareFrom);

        // use the full balance so it's easier to check if everything has been redeemed.
        uint256 amount = IERC20(address(pool)).balanceOf(address(this));

        // Stargate Pool LP -> Underlying Token
        stargateRouter.instantRedeemLocal(poolId, amount, address(this));
        require(IERC20(address(pool)).balanceOf(address(this)) == 0, "Cannot fully redeem");

        // underlying -> MIM
        (bool success, ) = zeroXExchangeProxy.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        // Refund remaining underlying balance to the recipient
        underlyingToken.safeTransfer(recipient, underlyingToken.balanceOf(address(this)));

        (, shareReturned) = bentoBox.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
