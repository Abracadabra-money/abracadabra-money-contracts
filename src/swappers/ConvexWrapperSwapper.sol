// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "swappers/CurveSwapper.sol";
import "libraries/SafeApprove.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IConvexWrapper.sol";
import "interfaces/ICurvePool.sol";

contract ConvexWrapperSwapper is CurveSwapper {
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
        CurveSwapper(
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
        if (_curvePoolDepositor != address(0)) {
            IERC20 curveToken = IERC20(wrapper.curveToken());
            curveToken.safeApprove(_curvePoolDepositor, type(uint256).max);
        }
    }

    function withdrawFromBentoBox(uint256 shareFrom) internal override returns (uint256 amount) {
        (amount, ) = bentoBox.withdraw(IERC20(address(wrapper)), address(this), address(this), 0, shareFrom);

        // ConvexWrapper -> CurveLP token
        wrapper.withdrawAndUnwrap(amount);
    }
}
