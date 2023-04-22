// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "periphery/Create3Factory.sol";
import "periphery/LiquidationHelper.sol";

contract Create3FactoryScript is BaseScript {
    function run() public {
        startBroadcast();

        new Create3Factory{salt: keccak256("Create3FactoryScript.s.sol-20230421-v1")}();

        stopBroadcast();
    }
}
