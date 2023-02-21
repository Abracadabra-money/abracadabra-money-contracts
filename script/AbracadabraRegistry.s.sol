// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "periphery/AbracadabraRegistry.sol";

contract AbracadabraRegistryScript is BaseScript {
    function run() public returns (AbracadabraRegistry registry) {
        startBroadcast();

        registry = new AbracadabraRegistry{salt: bytes32(bytes("AbracadabraRegistry.s.sol-v1"))}();

        stopBroadcast();
    }
}
