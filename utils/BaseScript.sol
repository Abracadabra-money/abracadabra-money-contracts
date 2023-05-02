// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DeployScript, Deployer} from "forge-deploy/DeployScript.sol";
import {DeployerFunctions} from "generated/deployer/DeployerFunctions.g.sol";
import "utils/Constants.sol";

abstract contract BaseScript is DeployScript {
    Constants internal immutable constants = new Constants(vm);
    bool internal testing;

    function setTesting(bool _testing) public {
        testing = _testing;
    }

    function startBroadcast() public {
        if (!testing) {
            vm.startBroadcast();
        }
    }

    function stopBroadcast() public {
        if (!testing) {
            vm.stopBroadcast();
        }
    }

    function saveDeployment(string memory name, address deployed, string memory filename, string memory contractName, bytes memory args) internal {
        string memory artifact = string.concat(filename, ":", contractName);
        bytes memory bytecode = deployed.code;

        deployer.save(name, deployed, bytecode, args, artifact);
    }
}
