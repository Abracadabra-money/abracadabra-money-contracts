// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "libraries/SafeApprove.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/ICurvePool.sol";

contract CurveLevSwapper is ILevSwapperV2 {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    error ErrSwapFailed();
    error ErrUnsupportedCurvePool();
    error ErrUnsupportedCurvePoolLength();

    IBentoBoxV1 public immutable bentoBox;
    IERC20 public immutable curveToken;
    IERC20 public immutable mim;
    CurvePoolInterfaceType public immutable curvePoolInterfaceType;
    address public immutable zeroXExchangeProxy;
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
        address _zeroXExchangeProxy
    ) {
        bentoBox = _bentoBox;
        curveToken = _curveToken;
        mim = _mim;
        zeroXExchangeProxy = _zeroXExchangeProxy;
        curvePoolCoinsLength = _poolTokens.length;
        curvePoolInterfaceType = _curvePoolInterfaceType;
        curvePool = _curvePool;

        _mim.approve(_zeroXExchangeProxy, type(uint256).max);

        address depositor = _curvePool;

        if (_curvePoolDepositor != address(0)) {
            depositor = _curvePoolDepositor;
        }

        for (uint256 i = 0; i < _poolTokens.length; i++) {
            _poolTokens[i].safeApprove(address(depositor), type(uint256).max);
        }

        curvePoolDepositor = depositor;
    }

    function depositInBentoBox(uint256 amount, address recipient) internal virtual returns (uint256 shareReturned) {
        (, shareReturned) = bentoBox.deposit(curveToken, address(bentoBox), recipient, amount, 0);
    }

    /// @inheritdoc ILevSwapperV2
    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        (IERC20 underlyingToken, uint256 poolIndex, bytes memory swapData) = abi.decode(data, (IERC20, uint256, bytes));
        bentoBox.withdraw(mim, address(this), address(this), 0, shareFrom);

        // Optional MIM -> Asset
        if (swapData.length != 0) {
            (bool success, ) = zeroXExchangeProxy.call(swapData);
            if (!success) {
                revert ErrSwapFailed();
            }
        }

        // Asset -> Curve LP
        if (curvePoolInterfaceType == CurvePoolInterfaceType.ICURVE_3POOL_ZAPPER) {
            _addLiquidityUsing3PoolZapper(underlyingToken, poolIndex);
        } else if (
            curvePoolInterfaceType == CurvePoolInterfaceType.ICURVE_POOL ||
            curvePoolInterfaceType == CurvePoolInterfaceType.IFACTORY_POOL ||
            curvePoolInterfaceType == CurvePoolInterfaceType.ITRICRYPTO_POOL
        ) {
            _addLiquidityCurvePool(underlyingToken, poolIndex);
        } else {
            revert ErrUnsupportedCurvePool();
        }

        // CurveLP -> Convex Wrapper LP
        uint256 _amount = curveToken.balanceOf(address(this));
        shareReturned = depositInBentoBox(_amount, recipient);
        extraShare = shareReturned - shareToMin;
    }

    function _addLiquidityUsing3PoolZapper(IERC20 underlyingToken, uint256 poolIndex) internal {
        uint256[4] memory amounts;
        amounts[poolIndex] = underlyingToken.balanceOf(address(this));
        ICurve3PoolZapper(curvePoolDepositor).add_liquidity(curvePool, amounts, 0);
    }

    function _addLiquidityCurvePool(IERC20 underlyingToken, uint256 poolIndex) internal {
        if (curvePoolCoinsLength == 2) {
            uint256[2] memory amounts;
            amounts[poolIndex] = underlyingToken.balanceOf(address(this));
            ICurvePool(curvePoolDepositor).add_liquidity(amounts, 0);
        } else if (curvePoolCoinsLength == 3) {
            uint256[3] memory amounts;
            amounts[poolIndex] = underlyingToken.balanceOf(address(this));
            ICurvePool(curvePoolDepositor).add_liquidity(amounts, 0);
        } else if (curvePoolCoinsLength == 4) {
            uint256[4] memory amounts;
            amounts[poolIndex] = underlyingToken.balanceOf(address(this));
            ICurvePool(curvePoolDepositor).add_liquidity(amounts, 0);
        } else {
            revert ErrUnsupportedCurvePoolLength();
        }
    }
}
