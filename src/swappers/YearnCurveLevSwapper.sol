// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {CurveLevSwapper} from "/swappers/CurveLevSwapper.sol";
import {IYearnVault} from "/interfaces/IYearnVault.sol";
import {ICurvePool, CurvePoolInterfaceType} from "/interfaces/ICurvePool.sol";

contract YearnCurveLevSwapper is CurveLevSwapper {
    using SafeTransferLib for address;

    IYearnVault public immutable wrapper;

    constructor(
        IBentoBoxLite _box,
        IYearnVault _wrapper,
        address _mim,
        CurvePoolInterfaceType _curvePoolInterfaceType,
        address _curvePool,
        address _curvePoolDepositor /* Optional Curve Deposit Zapper */,
        address[] memory _poolTokens
    ) CurveLevSwapper(_box, _wrapper.token(), _mim, _curvePoolInterfaceType, _curvePool, _curvePoolDepositor, _poolTokens) {
        wrapper = _wrapper;
        curveToken.safeApprove(address(_wrapper), type(uint256).max);
    }

    function depositInBentoBox(uint256 amount, address recipient) internal override returns (uint256 shareReturned) {
        // CurveLP -> Yearn Vault
        amount = wrapper.deposit(amount, address(box));

        (, shareReturned) = box.deposit(address(wrapper), address(box), recipient, amount, 0);
    }
}
