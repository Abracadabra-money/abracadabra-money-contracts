// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "mixins/Create3Factory.sol";

contract Create3FactoryScript is BaseScript {
    using DeployerFunctions for Deployer;

    function deploy() public {
        // salt is a uint256 salt
        DeployOptions memory options = DeployOptions({salt: uint256(keccak256("Create3Factory-1686617339"))});

        string memory deploymentName = string.concat(toolkit.getChainName(block.chainid), "_Create3Factory");
        deployer.deploy_Create3Factory(deploymentName, options);
    }
}
