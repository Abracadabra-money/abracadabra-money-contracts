// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {CurveSwapper} from "/swappers/CurveSwapper.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";
import {ICurvePool, CurvePoolInterfaceType} from "/interfaces/ICurvePool.sol";

contract MagicCurveLpSwapper is CurveSwapper {
    using SafeTransferLib for address;
    IERC4626 public immutable vault;

    constructor(
        IBentoBoxLite _box,
        IERC4626 _vault,
        address _mim,
        CurvePoolInterfaceType _curvePoolInterfaceType,
        address _curvePool,
        address _curvePoolDepositor /* Optional Curve Deposit Zapper */,
        address[] memory _poolTokens
    ) CurveSwapper(_box, address(_vault.asset()), _mim, _curvePoolInterfaceType, _curvePool, _curvePoolDepositor, _poolTokens) {
        vault = _vault;
        if (_curvePoolDepositor != address(0)) {
            address curveToken = _vault.asset();
            curveToken.safeApprove(_curvePoolDepositor, type(uint256).max);
        }
    }

    function withdrawFromBentoBox(uint256 shareFrom) internal override returns (uint256 amount) {
        (amount, ) = box.withdraw(address(vault), address(this), address(this), 0, shareFrom);

        // MagicCurveLP -> CurveLP
        amount = vault.redeem(amount, address(this), address(this));
    }
}
