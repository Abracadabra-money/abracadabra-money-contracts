// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {CurveSwapper} from "/swappers/CurveSwapper.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {IConvexWrapper} from "/interfaces/IConvexWrapper.sol";
import {CurvePoolInterfaceType} from "/interfaces/ICurvePool.sol";

contract ConvexWrapperSwapper is CurveSwapper {
    using SafeTransferLib for address;

    IConvexWrapper public immutable wrapper;

    constructor(
        IBentoBoxLite _bentoBox,
        IConvexWrapper _wrapper,
        address _mim,
        CurvePoolInterfaceType _curvePoolInterfaceType,
        address _curvePool,
        address _curvePoolDepositor /* Optional Curve Deposit Zapper */,
        address[] memory _poolTokens
    )
        CurveSwapper(
            _bentoBox,
            _wrapper.curveToken(),
            _mim,
            _curvePoolInterfaceType,
            _curvePool,
            _curvePoolDepositor,
            _poolTokens
        )
    {
        wrapper = _wrapper;
        if (_curvePoolDepositor != address(0)) {
            address curveToken = wrapper.curveToken();
            curveToken.safeApprove(_curvePoolDepositor, type(uint256).max);
        }
    }

    function withdrawFromBentoBox(uint256 shareFrom) internal override returns (uint256 amount) {
        (amount, ) = box.withdraw(address(wrapper), address(this), address(this), 0, shareFrom);

        // ConvexWrapper -> CurveLP token
        wrapper.withdrawAndUnwrap(amount);
    }
}
