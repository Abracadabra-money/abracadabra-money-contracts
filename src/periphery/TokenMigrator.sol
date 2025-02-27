// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Owned} from "@solmate/auth/Owned.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

contract TokenMigrator is Owned {
    using SafeTransferLib for address;

    event LogMigrated(uint256 amount);
    event LogRecovered(address indexed token, address indexed to, uint256 amount);

    address public immutable tokenIn;
    address public immutable tokenOut;

    constructor(address _tokenIn, address _tokenOut, address _owner) Owned(_owner) {
        tokenIn = _tokenIn;
        tokenOut = _tokenOut;
    }

    function migrate(uint256 amount) external {
        tokenIn.safeTransferFrom(msg.sender, address(this), amount);
        tokenOut.safeTransfer(msg.sender, amount);
        emit LogMigrated(amount);
    }

    function recover(address token, uint256 amount, address to) external onlyOwner {
        token.safeTransfer(to, amount);
        emit LogRecovered(token, to, amount);
    }
}
