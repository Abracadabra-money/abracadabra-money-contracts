// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {CurveLevSwapper} from "/swappers/CurveLevSwapper.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";
import {ICurvePool, CurvePoolInterfaceType} from "/interfaces/ICurvePool.sol";

contract MagicCurveLpLevSwapper is CurveLevSwapper {
    using SafeTransferLib for address;

    IERC4626 public immutable vault;

    constructor(
        IBentoBoxLite _bentoBox,
        IERC4626 _vault,
        address _mim,
        CurvePoolInterfaceType _curvePoolInterfaceType,
        address _curvePool,
        CurvePoolInterfaceType,
        address _curvePoolDepositor /* Optional Curve Deposit Zapper */,
        address[] memory _poolTokens
    ) CurveLevSwapper(_bentoBox, address(_vault.asset()), _mim, _curvePoolInterfaceType, _curvePool, _curvePoolDepositor, _poolTokens) {
        vault = _vault;
        curveToken.safeApprove(address(_vault), type(uint256).max);
    }

    function depositInBentoBox(uint256 amount, address recipient) internal override returns (uint256 shareReturned) {
        // CurveLP -> MagicCurveLP
        amount = vault.deposit(amount, address(box));

        (, shareReturned) = box.deposit(address(vault), address(box), recipient, amount, 0);
    }
}
