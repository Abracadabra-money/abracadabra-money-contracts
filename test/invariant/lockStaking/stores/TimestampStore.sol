// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @dev Because Foundry does not commit the state changes between invariant runs, we need to
/// save the current timestamp in a contract with persistent storage.
contract TimestampStore {
    uint256 public currentTimestamp;

    constructor() {
        currentTimestamp = block.timestamp;
    }

    function increaseCurrentTimestamp(uint256 timeJump) external {
        currentTimestamp += timeJump;
    }
}
