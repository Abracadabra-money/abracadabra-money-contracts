// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-deploy/DeployScript.sol";
import "generated/deployer/DeployerFunctions.g.sol";
import "utils/Constants.sol";
import "forge-std/console2.sol";

abstract contract BaseScript is DeployScript {
    Constants internal immutable constants = new Constants(vm);
    bool internal testing;

    function setTesting(bool _testing) public {
        testing = _testing;
    }

    function deployUsingCreate3(
        string memory deploymentName,
        bytes32 salt,
        bytes memory code,
        bytes memory constructorArgs,
        uint value
    ) internal returns (address instance) {
        if (testing) {
            deployer.ignoreDeployment(deploymentName);
        }

        if (deployer.has(deploymentName)) {
            return deployer.getAddress(deploymentName);
        } else {
            Create3Factory factory = Create3Factory(constants.getAddress(ChainId.All, "create3Factory"));
            instance = factory.deploy(salt, abi.encodePacked(code, constructorArgs), 0);

            if (!testing && vm.envOr("LIVE_DEPLOYMENT", false)) {
                string memory deploymentFile = string.concat("deployments/", vm.toString(block.chainid), "/", deploymentName, ".json");
                string memory content = string.concat('{ "address": "', vm.toString(instance), '" }');
                vm.writeFile(deploymentFile, content);
            }
        }
    }
}
