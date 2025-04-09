// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {CurveLevSwapper} from "/swappers/CurveLevSwapper.sol";
import {IConvexWrapper} from "/interfaces/IConvexWrapper.sol";
import {CurvePoolInterfaceType} from "/interfaces/ICurvePool.sol";

contract ConvexWrapperLevSwapper is CurveLevSwapper {
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
        CurveLevSwapper(
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
        curveToken.safeApprove(address(_wrapper), type(uint256).max);
    }

    function depositInBentoBox(uint256 amount, address recipient) internal override returns (uint256 shareReturned) {
        // CurveLP -> Convex Wrapper LP
        wrapper.deposit(amount, address(box));

        (, shareReturned) = box.deposit(address(wrapper), address(box), recipient, amount, 0);
    }
}
