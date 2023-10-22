// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {CurveLevSwapper} from "swappers/CurveLevSwapper.sol";
import {IConvexWrapper} from "interfaces/IConvexWrapper.sol";
import {CurvePoolInterfaceType} from "interfaces/ICurvePool.sol";

contract ConvexWrapperLevSwapper is CurveLevSwapper {
    using SafeTransferLib for address;

    IConvexWrapper public immutable wrapper;

    constructor(
        IBentoBoxV1 _bentoBox,
        IConvexWrapper _wrapper,
        address _mim,
        CurvePoolInterfaceType _curvePoolInterfaceType,
        address _curvePool,
        address _curvePoolDepositor /* Optional Curve Deposit Zapper */,
        address[] memory _poolTokens,
        address _zeroXExchangeProxy
    )
        CurveLevSwapper(
            _bentoBox,
            _wrapper.curveToken(),
            _mim,
            _curvePoolInterfaceType,
            _curvePool,
            _curvePoolDepositor,
            _poolTokens,
            _zeroXExchangeProxy
        )
    {
        wrapper = _wrapper;
        curveToken.safeApprove(address(_wrapper), type(uint256).max);
    }

    function depositInBentoBox(uint256 amount, address recipient) internal override returns (uint256 shareReturned) {
        // CurveLP -> Convex Wrapper LP
        wrapper.deposit(amount, address(bentoBox));

        (, shareReturned) = bentoBox.deposit(IERC20(address(wrapper)), address(bentoBox), recipient, amount, 0);
    }
}
