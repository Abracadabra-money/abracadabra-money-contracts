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

contract CurveSwapper is ISwapperV2 {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    error ErrSwapFailed();
    error ErrTokenNotSupported(IERC20);
    error ErrUnsupportedCurvePool();

    CurvePoolInterfaceType public immutable curvePoolInterfaceType;
    IBentoBoxV1 public immutable bentoBox;
    IERC20 public immutable curveToken;
    IERC20 public immutable mim;
    address public immutable exchange;
    address public immutable curvePool;
    address public immutable curvePoolDepositor;
    uint256 public immutable curvePoolCoinsLength;

    constructor(
        IBentoBoxV1 _bentoBox,
        IERC20 _curveToken,
        IERC20 _mim,
        CurvePoolInterfaceType _curvePoolInterfaceType,
        address _curvePool,
        address _curvePoolDepositor /* Optional Curve Deposit Zapper */,
        IERC20[] memory _poolTokens,
        address _exchange
    ) {
        bentoBox = _bentoBox;
        curveToken = _curveToken;
        mim = _mim;
        curvePoolInterfaceType = _curvePoolInterfaceType;
        curvePool = _curvePool;
        exchange = _exchange;
        curvePoolCoinsLength = _poolTokens.length;

        address depositor = _curvePool;

        if (_curvePoolDepositor != address(0)) {
            depositor = _curvePoolDepositor;
        }

        curvePoolDepositor = depositor;

        for (uint256 i = 0; i < _poolTokens.length; i++) {
            _poolTokens[i].safeApprove(_exchange, type(uint256).max);
        }

        mim.approve(address(_bentoBox), type(uint256).max);
    }

    function withdrawFromBentoBox(uint256 shareFrom) internal virtual returns (uint256 amount) {
        (amount, ) = bentoBox.withdraw(curveToken, address(this), address(this), 0, shareFrom);
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
        uint256 amount = withdrawFromBentoBox(shareFrom);

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

        // Optional underlyingToken -> MIM
        if (swapData.length != 0) {
            (bool success, ) = exchange.call(swapData);
            if (!success) {
                revert ErrSwapFailed();
            }
        }

        (, shareReturned) = bentoBox.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
