// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Operatable} from "mixins/Operatable.sol";
import {IMintableBurnable} from "interfaces/IMintableBurnable.sol";

/// @title ElevatedMinterBurner
/// @notice ElevatedMinterBurner is a periphery contract for minting and burning tokens and executing arbitrary calls.
contract ElevatedMinterBurner is IMintableBurnable, Operatable {
    IMintableBurnable public immutable token;

    constructor(IMintableBurnable token_) {
        token = token_;
    }

    function burn(address from, uint256 amount) external override onlyOperators returns (bool) {
        return token.burn(from, amount);
    }

    function mint(address to, uint256 amount) external override onlyOperators returns (bool) {
        return token.mint(to, amount);
    }

    function exec(address target, bytes calldata data) external onlyOwner {
        (bool success, bytes memory result) = target.call(data);
        if (!success) {
            if (result.length == 0) revert();
            assembly {
                revert(add(32, result), mload(result))
            }
        }
    }
}
