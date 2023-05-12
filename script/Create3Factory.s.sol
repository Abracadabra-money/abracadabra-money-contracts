// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/LegacyBaseScript.sol";
import "mixins/Create3Factory.sol";

contract Create3FactoryScript is LegacyBaseScript {
    function run() public {
        startBroadcast();

        new Create3Factory{salt: keccak256("Create3FactoryScript.s.sol-20230421-v1")}();

        stopBroadcast();
    }
}
