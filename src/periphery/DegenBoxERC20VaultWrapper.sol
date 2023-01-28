// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "libraries/SafeApprove.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IERC20Vault.sol";

/// @notice Wrap token to wrapper and deposit into DegenBox for recipient
/// Need to be used atomically, do not transfer fund in it and then wrap / unwrap on another block as
/// it could be retrieve by anyone else, by calling wrap or unwrap.
contract DegenBoxERC20VaultWrapper {
    using SafeApprove for IERC20;

    IBentoBoxV1 immutable degenBox;
    IERC20Vault immutable wrapper;
    IERC20 immutable underlying;

    constructor(IBentoBoxV1 _degenBox, IERC20Vault _wrapper) {
        degenBox = _degenBox;
        wrapper = _wrapper;

        IERC20 _underlying = wrapper.underlying();
        _underlying.approve(address(wrapper), type(uint256).max);

        underlying = _underlying;
    }

    function wrap(address recipient, uint256 amount) external returns (uint256 amountOut, uint256 shareOut) {
        uint256 shares = wrapper.enterFor(amount, address(degenBox));
        return degenBox.deposit(wrapper, address(degenBox), recipient, shares, 0);
    }

    function unwrap(address recipient, uint256 shares) external returns (uint256 amountOut, uint256 shareOut) {
        uint amount = wrapper.leaveTo(shares, address(degenBox));
        return degenBox.deposit(underlying, address(degenBox), recipient, amount, 0);
    }
}
