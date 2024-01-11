// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";

contract Create3FactoryScript is BaseScript {
    function deploy() public {
        vm.startBroadcast();
        deploy("Create3Factory", "Create3Factory.sol:Create3Factory", "");
        vm.stopBroadcast();
    }
}
