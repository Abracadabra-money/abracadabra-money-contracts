// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "periphery/AbracadabraRegistry.sol";

contract AbracadabraRegistryScript is BaseScript {
    function run() public returns (AbracadabraRegistry registry) {
        startBroadcast();

        address newOwner = 0x8Dc7371d855BCF361655ACE52Eaea10C78eF579e;

        registry = new AbracadabraRegistry();

        if (!testing) {
            registry.set("markets", "QmcCagY5QJVQBGKWUfaj8zahAJWNGY5Fje35YJ9BNiQpRU");
            registry.setOperator(tx.origin, false);
            registry.setOperator(newOwner, true);
            registry.transferOwnership(newOwner, true, false);
        }

        stopBroadcast();
    }
}
