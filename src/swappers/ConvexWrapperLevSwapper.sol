// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "libraries/SafeApprove.sol";
import "interfaces/IBentoBoxV1.sol";
import "swappers/CurveLevSwapper.sol";
import "interfaces/IConvexWrapper.sol";
import "interfaces/ICurvePool.sol";

contract ConvexWrapperLevSwapper is CurveLevSwapper {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    IConvexWrapper public immutable wrapper;

    constructor(
        IBentoBoxV1 _bentoBox,
        IConvexWrapper _wrapper,
        IERC20 _mim,
        CurvePoolInterfaceType _curvePoolInterfaceType,
        address _curvePool,
        address _curvePoolDepositor /* Optional Curve Deposit Zapper */,
        IERC20[] memory _poolTokens,
        address _zeroXExchangeProxy
    )
        CurveLevSwapper(
            _bentoBox,
            IERC20(_wrapper.curveToken()),
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
