// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20WithSupply} from "BoringSolidity/ERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/IERC20Vault.sol";

/// @notice A token that behaves like SushiBar where the contract underlying token balance
/// influences the share value.
contract ERC20Vault is IERC20Vault, ERC20WithSupply {
    using BoringERC20 for IERC20;

    IERC20 public underlying;
    uint8 public immutable decimals;

    string public name;
    string public symbol;

    constructor(
        IERC20 _underlying,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        underlying = _underlying;
    }
    
    function _enter(uint256 amount, address recipient) internal returns (uint256 shares) {
        shares = toShares(amount);
        _mint(recipient, shares);
        underlying.safeTransferFrom(msg.sender, address(this), amount);
    }

    function _leave(uint256 shares, address recipient) internal returns (uint256 amount) {
        amount = toAmount(shares);
        _burn(msg.sender, shares);
        underlying.safeTransfer(recipient, amount);
    }

    function enter(uint256 amount) external returns (uint256 shares) {
        return _enter(amount, msg.sender);
    }

    function enterFor(uint256 amount, address recipient) external returns (uint256 shares) {
        return _enter(amount, recipient);
    }

    function leave(uint256 shares) external returns (uint256 amount) {
        return _leave(shares, msg.sender);
    }

    function leaveTo(uint256 shares, address recipient) external returns (uint256 amount) {
        return _leave(shares, recipient);
    }

    function leaveAll() external returns (uint256 amount) {
        return _leave(balanceOf[msg.sender], msg.sender);
    }

    function leaveAllTo(address recipient) external returns (uint256 amount) {
        return _leave(balanceOf[msg.sender], recipient);
    }

    function toAmount(uint256 shares) public view returns (uint256) {
        uint256 totalUnderlying = underlying.balanceOf(address(this));
        return (totalSupply == 0 || totalUnderlying == 0) ? shares : (shares * totalUnderlying) / totalSupply;
    }

    function toShares(uint256 amount) public view returns (uint256) {
        uint256 totalUnderlying = underlying.balanceOf(address(this));
        return (totalSupply == 0 || totalUnderlying == 0) ? amount : (amount * totalSupply) / totalUnderlying;
    }
}
