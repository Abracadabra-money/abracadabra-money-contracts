// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import "BoringSolidity/ERC20.sol";
import "libraries/SafeTransferLib.sol";
import "interfaces/IUniswapV2Pair.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/IStargatePool.sol";
import "interfaces/IStargateRouter.sol";

/// @notice LP liquidation/deleverage swapper for Stargate LPs using Matcha/0x aggregator
contract ZeroXStargateLPSwapper is ISwapperV2 {
    using SafeTransferLib for ERC20;

    error ErrSwapFailed();

    IBentoBoxV1 public immutable bentoBox;
    IStargatePool public immutable pool;
    ERC20 public immutable mim;
    ERC20 public immutable underlyingToken;
    IStargateRouter public immutable stargateRouter;
    address public immutable zeroXExchangeProxy;

    uint16 public immutable poolId;

    constructor(
        IBentoBoxV1 _bentoBox,
        IStargatePool _pool,
        uint16 _poolId,
        IStargateRouter _stargateRouter,
        ERC20 _mim,
        address _zeroXExchangeProxy
    ) {
        bentoBox = _bentoBox;
        pool = _pool;
        poolId = _poolId;
        mim = _mim;
        stargateRouter = _stargateRouter;
        zeroXExchangeProxy = _zeroXExchangeProxy;
        underlyingToken = ERC20(_pool.token());

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
        bytes calldata data
    ) public override returns (uint256 extraShare, uint256 shareReturned) {
        bytes memory swapData = abi.decode(data, (bytes));
        bentoBox.withdraw(ERC20(address(pool)), address(this), address(this), 0, shareFrom);

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

        (, shareReturned) = bentoBox.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
