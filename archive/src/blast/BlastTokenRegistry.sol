// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";

contract BlastTokenRegistry is Owned {
    event LogNativeYieldTokenEnabled(address indexed token, bool enabled);
    error ErrZeroAddress();

    mapping(address => bool) public nativeYieldTokens;

    constructor(address _owner) Owned(_owner) {}

    function setNativeYieldTokenEnabled(address token, bool enabled) external onlyOwner {
        if (token == address(0)) {
            revert ErrZeroAddress();
        }

        nativeYieldTokens[token] = enabled;
        emit LogNativeYieldTokenEnabled(token, enabled);
    }
}
