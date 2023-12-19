// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {SafeApproveLib} from "libraries/SafeApproveLib.sol";
import {IStargatePool, IStargateRouter} from "interfaces/IStargate.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {ISwapperV1} from "interfaces/ISwapperV1.sol";
import {ICurvePool} from "interfaces/ICurvePool.sol";

interface IStargateLpMimPool {
    function swapForMim(IStargatePool tokenIn, uint256 amountIn, address recipient) external returns (uint256);
}

/// @notice Liquidation Swapper for Stargate LP using Curve
contract StargateCurveSwapper is ISwapperV1, BoringOwnable {
    using BoringERC20 for IERC20;
    using SafeApproveLib for IERC20;
    using Address for address;

    event MimPoolChanged(IStargateLpMimPool previousPool, IStargateLpMimPool pool);

    IBentoBoxV1 public immutable degenBox;
    IStargatePool public immutable pool;
    IStargateRouter public immutable stargateRouter;
    ICurvePool public immutable curvePool;
    int128 public immutable curvePoolI;
    int128 public immutable curvePoolJ;
    uint16 public immutable poolId;
    IERC20 public immutable underlyingPoolToken;
    IERC20 public immutable mim;

    IStargateLpMimPool public mimPool;

    constructor(
        IBentoBoxV1 _degenBox,
        IStargatePool _pool,
        uint16 _poolId,
        IStargateRouter _stargateRouter,
        ICurvePool _curvePool,
        int128 _curvePoolI,
        int128 _curvePoolJ
    ) {
        degenBox = _degenBox;
        pool = _pool;
        poolId = _poolId;
        stargateRouter = _stargateRouter;
        curvePool = _curvePool;
        curvePoolI = _curvePoolI;
        curvePoolJ = _curvePoolJ;
        mim = IERC20(_curvePool.coins(uint128(_curvePoolJ)));

        underlyingPoolToken = IERC20(_pool.token());
        underlyingPoolToken.safeApprove(address(_curvePool), type(uint256).max);
    }

    function setMimPool(IStargateLpMimPool _mimPool) external onlyOwner {
        if (address(mimPool) != address(0)) {
            IERC20(address(pool)).safeApprove(address(_mimPool), 0);
        }

        if (address(_mimPool) != address(0)) {
            IERC20(address(pool)).safeApprove(address(_mimPool), type(uint256).max);
        }

        emit MimPoolChanged(mimPool, _mimPool);
        mimPool = _mimPool;
    }

    /// @inheritdoc ISwapperV1
    function swap(
        address,
        address,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom
    ) public override returns (uint256 extraShare, uint256 shareReturned) {
        degenBox.withdraw(IERC20(address(pool)), address(this), address(this), 0, shareFrom);

        // use the full balance so it's easier to check if everything has been redeemed.
        uint256 amount = IERC20(address(pool)).balanceOf(address(this));
        uint256 mimAmount;

        // Stargate Pool LP -> Underlying Token
        stargateRouter.instantRedeemLocal(poolId, amount, address(this));

        // Use mim pool to swap the remaining lp
        if (address(mimPool) != address(0)) {
            // Remaining lp amount
            amount = IERC20(address(pool)).balanceOf(address(this));

            if (amount > 0) {
                mimAmount += mimPool.swapForMim(pool, amount, address(degenBox));
            }
        } else {
            require(IERC20(address(pool)).balanceOf(address(this)) == 0, "Cannot fully redeem");
        }

        // Stargate Pool Underlying Token -> MIM
        mimAmount += curvePool.exchange_underlying(
            curvePoolI,
            curvePoolJ,
            underlyingPoolToken.balanceOf(address(this)),
            0,
            address(degenBox)
        );

        (, shareReturned) = degenBox.deposit(mim, address(degenBox), recipient, mimAmount, 0);
        extraShare = shareReturned - shareToMin;
    }
}
