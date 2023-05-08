// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";

contract TestScript is BaseScript {
    using DeployerFunctions for Deployer;

    function deploy() public {
        deployer.deploy_TestContract("TestContract", "foobar", tx.origin);
    }
}
