// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";

contract MyScript is BaseScript {
    using DeployerFunctions for Deployer;

    function run() public {
        startBroadcast();

        // Deployment here.

        stopBroadcast();
    }
}
