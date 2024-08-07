// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Owned} from "@solmate/auth/Owned.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

contract FixedTokenExchange is Owned, Pausable {
    using SafeTransferLib for address;

    address public immutable tokenIn;
    address public immutable tokenOut;

    constructor(address _tokenIn, address _tokenOut, address _owner) Owned(_owner) {
        tokenIn = _tokenIn;
        tokenOut = _tokenOut;
    }

    function deposit(uint256 amount) external {
        tokenIn.safeTransferFrom(msg.sender, address(this), amount);
        tokenOut.safeTransfer(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        tokenOut.safeTransferFrom(msg.sender, address(this), amount);
        tokenIn.safeTransfer(msg.sender, amount);
    }

    function recover(address token, uint256 amount) external onlyOwner {
        token.safeTransfer(msg.sender, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
