// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "periphery/KeyValueRegistry.sol";

contract KeyValueRegistryScript is BaseScript {
    function deploy() public {
        startBroadcast();

        new KeyValueRegistry{salt: bytes32(bytes("KeyValueRegistry.sol-20230222-v1"))}(tx.origin);

        stopBroadcast();
    }
}
