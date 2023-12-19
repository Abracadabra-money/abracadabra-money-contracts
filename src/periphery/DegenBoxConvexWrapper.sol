// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {SafeApproveLib} from "libraries/SafeApproveLib.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {IConvexWrapper} from "interfaces/IConvexWrapper.sol";

/// @notice Wrap token to ConvexWrapper and deposit into DegenBox for recipient
/// Need to be used atomically, do not transfer fund in it and then wrap / unwrap on another block as
/// it could be retrieved by anyone else, by calling deposit or withdraw.
contract DegenBoxConvexWrapper {
    using SafeApproveLib for IERC20;

    IBentoBoxV1 immutable degenBox;
    IConvexWrapper immutable wrapper;
    IERC20 immutable underlying;

    constructor(IBentoBoxV1 _degenBox, IConvexWrapper _wrapper) {
        degenBox = _degenBox;
        wrapper = _wrapper;

        IERC20 _underlying = IERC20(wrapper.curveToken());
        _underlying.approve(address(wrapper), type(uint256).max);
        _underlying.approve(address(degenBox), type(uint256).max);
        underlying = _underlying;
    }

    function wrap(address recipient, uint256 amount) external returns (uint256 amountOut, uint256 shareOut) {
        wrapper.deposit(amount, address(degenBox));
        return degenBox.deposit(IERC20(address(wrapper)), address(degenBox), recipient, amount, 0);
    }

    function unwrap(address recipient, uint256 amount) external returns (uint256 amountOut, uint256 shareOut) {
        wrapper.withdrawAndUnwrap(amount);
        return degenBox.deposit(underlying, address(this), recipient, amount, 0);
    }
}
