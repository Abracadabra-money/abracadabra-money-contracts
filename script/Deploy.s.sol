// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";

contract MyScript is BaseScript {
    function run() public {
        vm.startBroadcast();

        // Deployment here.
        
        vm.stopBroadcast();
    }
}
