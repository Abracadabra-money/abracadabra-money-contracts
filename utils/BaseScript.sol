// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-deploy/DeployScript.sol";
import "generated/deployer/DeployerFunctions.g.sol";
import "utils/Toolkit.sol";

abstract contract BaseScript is DeployScript {
    Toolkit internal toolkit = getToolkit();

    function setTesting(bool _testing) public {
        toolkit.setTesting(_testing);
    }

    function testing() internal view returns (bool) {
        return toolkit.testing();
    }

    function deployUsingCreate3(
        string memory deploymentName,
        bytes32 salt,
        string memory artifactName,
        bytes memory constructorArgs,
        uint value
    ) internal returns (address instance) {
        Create3Factory factory = Create3Factory(toolkit.getAddress(ChainId.All, "create3Factory"));

        /// In testing environment always ignore the current deployment and deploy the factory
        /// when it's not deployed on the current blockheight.
        if (toolkit.testing()) {
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

            // avoid sending this transaction live when using startBroadcast/stopBroadcast
            (VmSafe.CallerMode callerMode, , ) = vm.readCallers();

            // should never be called in broadcast mode, since this would have been turn off by `factory.deploy` already.
            require(callerMode != VmSafe.CallerMode.Broadcast, "BaseScript: unexpected broadcast mode");

            if (callerMode == VmSafe.CallerMode.RecurrentBroadcast) {
                vm.stopBroadcast();
            }
            deployer.save(deploymentName, instance, artifactName, constructorArgs, creationCode);
            if (callerMode == VmSafe.CallerMode.RecurrentBroadcast) {
                vm.startBroadcast();
            }
        }
    }
}
