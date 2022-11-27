// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ITokenWrapper.sol";

/// @notice Wrap token to wrapper and deposit into DegenBox for recipient
contract DegenBoxTokenWrapper {
    function wrap(
        IBentoBoxV1 degenBox,
        ITokenWrapper wrapper,
        address recipient,
        uint256 amount
    ) external returns (uint256 amountOut, uint256 shareOut) {
        wrapper.underlying().approve(address(wrapper), amount);
        wrapper.wrapFor(amount, address(degenBox));
        return degenBox.deposit(wrapper, address(degenBox), recipient, amount, 0);
    }

    function unwrap(
        IBentoBoxV1 degenBox,
        ITokenWrapper wrapper,
        address recipient,
        uint256 amount
    ) external returns (uint256 amountOut, uint256 shareOut) {
        wrapper.unwrapTo(amount, address(degenBox));
        return degenBox.deposit(wrapper.underlying(), address(degenBox), recipient, amount, 0);
    }
}
