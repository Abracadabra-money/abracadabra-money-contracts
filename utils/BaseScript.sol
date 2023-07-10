// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-deploy/DeployScript.sol";
import "generated/deployer/DeployerFunctions.g.sol";
import "utils/Constants.sol";
import "forge-std/console2.sol";

abstract contract BaseScript is DeployScript {
    Constants internal immutable constants = ConstantsLib.singleton();
    bool internal testing;

    function run() public override returns (DeployerDeployment[] memory newDeployments) {
       return super.run();
    }

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
        // Always redeploy when testing, otherwise the address in the deployment file will be used
        // So if we made any changes to test, it won't load the new contract
        if (testing) {
            deployer.ignoreDeployment(deploymentName);
        }

        if (deployer.has(deploymentName)) {
            return deployer.getAddress(deploymentName);
        } else {
            Create3Factory factory = Create3Factory(constants.getAddress(ChainId.All, "create3Factory"));
            instance = factory.deploy(salt, abi.encodePacked(code, constructorArgs), value);

            if (!testing) {
                string memory deploymentFile = string.concat("deployments/", vm.toString(block.chainid), "/", deploymentName, ".json");
                string memory content = string.concat('{ "address": "', vm.toString(instance), '" }');
                vm.writeFile(deploymentFile, content);
            }
        }
    }
}
