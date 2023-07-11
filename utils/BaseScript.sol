// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-deploy/DeployScript.sol";
import "generated/deployer/DeployerFunctions.g.sol";
import "utils/Constants.sol";

abstract contract BaseScript is DeployScript {
    Constants internal constants;
    bool internal testing;

    function run() public override returns (DeployerDeployment[] memory newDeployments) {
        constants = ConstantsLib.singleton();
        return super.run();
    }

    function setTesting(bool _testing) public {
        testing = _testing;

        if (_testing) {
            constants = ConstantsLib.singleton();
        }
    }

    function deployUsingCreate3(
        string memory deploymentName,
        bytes32 salt,
        string memory artifactName,
        bytes memory constructorArgs,
        uint value
    ) internal returns (address instance) {
        Create3Factory factory = Create3Factory(constants.getAddress(ChainId.All, "create3Factory"));

        /// In testing environment always ignore the current deployment and deploy the factory
        /// when it's not deployed on the current blockheight.
        if (testing) {
            deployer.ignoreDeployment(deploymentName);

            if (address(factory).code.length == 0) {
                Create3Factory newFactory = new Create3Factory();
                vm.etch(address(factory), address(newFactory).code);
                vm.makePersistent(address(factory));
                vm.etch(address(newFactory), "");
            }
        }

        if (deployer.has(deploymentName)) {
            return deployer.getAddress(deploymentName);
        } else {
            bytes memory creationCode = vm.getCode(artifactName);
            instance = factory.deploy(salt, abi.encodePacked(creationCode, constructorArgs), value);
            deployer.save(deploymentName, instance, artifactName, constructorArgs, creationCode);
        }
    }
}
