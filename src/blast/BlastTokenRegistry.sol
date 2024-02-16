// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";

contract BlastTokenRegistry is Owned {
    event LogNativeYieldTokenRegistered(address indexed token);
    error ErrZeroAddress();

    mapping(address => bool) public nativeYieldTokens;

    constructor(address _owner) Owned(_owner) {}

    function registerNativeYieldToken(address token) external onlyOwner {
        if (token == address(0)) {
            revert ErrZeroAddress();
        }

        nativeYieldTokens[token] = true;
        emit LogNativeYieldTokenRegistered(token);
    }
}
