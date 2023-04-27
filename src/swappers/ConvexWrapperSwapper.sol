// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "libraries/SafeApprove.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/IConvexWrapper.sol";
import "interfaces/ICurvePool.sol";

contract ConvexWrapperSwapper is ISwapperV2 {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    error ErrSwapFailed();
    error ErrTokenNotSupported(IERC20);
    error ErrUnsupportedCurvePool();

    CurvePoolInterfaceType public immutable curvePoolInterfaceType;
    IBentoBoxV1 public immutable bentoBox;
    IConvexWrapper public immutable wrapper;
    IERC20 public immutable mim;
    address public immutable zeroXExchangeProxy;
    address public immutable curvePool;
    address public immutable curvePoolDepositor;
    uint256 public immutable curvePoolCoinsLength;

    constructor(
        IBentoBoxV1 _bentoBox,
        IConvexWrapper _wrapper,
        IERC20 _mim,
        CurvePoolInterfaceType _curvePoolInterfaceType,
        address _curvePool,
        address _curvePoolDepositor /* Optional, usually a Curve Deposit Zapper */,
        IERC20[] memory _poolTokens,
        address _zeroXExchangeProxy
    ) {
        bentoBox = _bentoBox;
        wrapper = _wrapper;
        mim = _mim;
        curvePoolInterfaceType = _curvePoolInterfaceType;
        curvePool = _curvePool;
        zeroXExchangeProxy = _zeroXExchangeProxy;
        curvePoolCoinsLength = _poolTokens.length;

        address depositor = _curvePool;

        if (_curvePoolDepositor != address(0)) {
            depositor = _curvePoolDepositor;
            IERC20 curveToken = IERC20(wrapper.curveToken());
            curveToken.safeApprove(_curvePoolDepositor, type(uint256).max);
        }

        curvePoolDepositor = depositor;

        for (uint256 i = 0; i < _poolTokens.length; i++) {
            _poolTokens[i].safeApprove(_zeroXExchangeProxy, type(uint256).max);
        }

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
        (uint256 poolIndex, bytes memory swapData) = abi.decode(data, (uint256, bytes));
        (uint256 amount, ) = bentoBox.withdraw(IERC20(address(wrapper)), address(this), address(this), 0, shareFrom);

        // ConvexWrapper -> CurveLP token
        wrapper.withdrawAndUnwrap(amount);

        // CurveLP token -> underlyingToken
        if (curvePoolInterfaceType == CurvePoolInterfaceType.ICURVE_POOL) {
            ICurvePool(curvePoolDepositor).remove_liquidity_one_coin(amount, int128(uint128(poolIndex)), uint256(0));
        } else if (curvePoolInterfaceType == CurvePoolInterfaceType.ICURVE_3POOL_ZAPPER) {
            ICurve3PoolZapper(curvePoolDepositor).remove_liquidity_one_coin(curvePool, amount, int128(uint128(poolIndex)), uint256(0));
        } else if (curvePoolInterfaceType == CurvePoolInterfaceType.IFACTORY_POOL) {
            IFactoryPool(curvePoolDepositor).remove_liquidity_one_coin(amount, poolIndex, uint256(0));
        } else if (curvePoolInterfaceType == CurvePoolInterfaceType.ITRICRYPTO_POOL) {
            ITriCrypto(curvePoolDepositor).remove_liquidity_one_coin(amount, poolIndex, uint256(0));
        } else {
            revert ErrUnsupportedCurvePool();
        }

        // underlyingToken -> MIM
        (bool success, ) = zeroXExchangeProxy.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        (, shareReturned) = bentoBox.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
