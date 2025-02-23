// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {ICurvePool, CurvePoolInterfaceType, ICurve3PoolZapper} from "/interfaces/ICurvePool.sol";

contract CurveLevSwapper is ILevSwapperV2 {
    using SafeTransferLib for address;

    error ErrSwapFailed();
    error ErrUnsupportedCurvePool();
    error ErrUnsupportedCurvePoolLength();

    IBentoBoxLite public immutable box;
    address public immutable curveToken;
    address public immutable mim;
    CurvePoolInterfaceType public immutable curvePoolInterfaceType;
    address public immutable curvePool;
    address public immutable curvePoolDepositor;
    uint256 public immutable curvePoolCoinsLength;

    constructor(
        IBentoBoxLite _box,
        address _curveToken,
        address _mim,
        CurvePoolInterfaceType _curvePoolInterfaceType,
        address _curvePool,
        address _curvePoolDepositor /* Optional Curve Deposit Zapper */,
        address[] memory _poolTokens
    ) {
        box = _box;
        curveToken = _curveToken;
        mim = _mim;
        curvePoolCoinsLength = _poolTokens.length;
        curvePoolInterfaceType = _curvePoolInterfaceType;
        curvePool = _curvePool;

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
        (, shareReturned) = box.deposit(curveToken, address(box), recipient, amount, 0);
    }

    /// @inheritdoc ILevSwapperV2
    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        (address underlyingToken, uint256 poolIndex, address to, bytes memory swapData) = abi.decode(data, (address, uint256, address, bytes));
        box.withdraw(mim, address(this), address(this), 0, shareFrom);

        if (IERC20(mim).allowance(address(this), to) != type(uint256).max) {
            mim.safeApprove(to, type(uint256).max);
        }

        // Optional MIM -> Asset
        if (swapData.length != 0) {
            (bool success, ) = to.call(swapData);
            if (!success) {
                revert ErrSwapFailed();
            }

            // Refund remaining underlying balance to the recipient
            mim.safeTransfer(recipient, mim.balanceOf(address(this)));
        }

        // Asset -> Curve LP
        if (curvePoolInterfaceType == CurvePoolInterfaceType.ICURVE_3POOL_ZAPPER) {
            _addLiquidityUsing3PoolZapper(underlyingToken, poolIndex);
        } else if (
            curvePoolInterfaceType == CurvePoolInterfaceType.ICURVE_POOL ||
            curvePoolInterfaceType == CurvePoolInterfaceType.ICURVE_POOL_LEGACY ||
            curvePoolInterfaceType == CurvePoolInterfaceType.IFACTORY_POOL ||
            curvePoolInterfaceType == CurvePoolInterfaceType.ITRICRYPTO_POOL
        ) {
            _addLiquidityCurvePool(underlyingToken, poolIndex);
        } else {
            revert ErrUnsupportedCurvePool();
        }

        uint256 _amount = curveToken.balanceOf(address(this));
        shareReturned = depositInBentoBox(_amount, recipient);
        extraShare = shareReturned - shareToMin;
    }

    function _addLiquidityUsing3PoolZapper(address underlyingToken, uint256 poolIndex) internal {
        uint256[4] memory amounts;
        amounts[poolIndex] = underlyingToken.balanceOf(address(this));
        ICurve3PoolZapper(curvePoolDepositor).add_liquidity(curvePool, amounts, 0);
    }

    function _addLiquidityCurvePool(address underlyingToken, uint256 poolIndex) internal {
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
