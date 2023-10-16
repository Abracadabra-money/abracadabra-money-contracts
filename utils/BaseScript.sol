// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {Deployer, DeployerDeployment, getDeployer} from "forge-deploy/Deployer.sol";
import {DefaultDeployerFunction} from "forge-deploy/DefaultDeployerFunction.sol";
import {Create3Factory} from "mixins/Create3Factory.sol";
import "utils/Toolkit.sol";

abstract contract BaseScript is Script {
    Toolkit internal toolkit = getToolkit();
    Deployer internal deployer = getDeployer();

    function run() public virtual returns (DeployerDeployment[] memory newDeployments) {
        _deploy();
        return deployer.newDeployments();
    }

    function _deploy() internal {
        bytes memory data = abi.encodeWithSignature("deploy()");

        (bool success, bytes memory returnData) = address(this).delegatecall(data);
        if (!success) {
            if (returnData.length > 0) {
                /// @solidity memory-safe-assembly
                assembly {
                    let returnDataSize := mload(returnData)
                    revert(add(32, returnData), returnDataSize)
                }
            } else {
                revert("FAILED_TO_CALL: deploy()");
            }
        }
    }

    function setTesting(bool _testing) public {
        toolkit.setTesting(_testing);
    }

    function testing() internal view returns (bool) {
        return toolkit.testing();
    }

    function deploy(string memory deploymentName, string memory artifactName) internal returns (address instance) {
        return deploy(deploymentName, artifactName, "");
    }

    function deploy(
        string memory deploymentName,
        string memory artifactName,
        bytes memory constructorArgs
    ) internal returns (address instance) {
        deploymentName = toolkit.prefixWithChainName(block.chainid, deploymentName);

        if (toolkit.testing()) {
            deployer.ignoreDeployment(deploymentName);
        }

        return DefaultDeployerFunction.deploy(deployer, deploymentName, artifactName, constructorArgs);
    }

    function deployUsingCreate3(
        string memory deploymentName,
        bytes32 salt,
        string memory artifactName,
        bytes memory constructorArgs,
        uint value
    ) internal returns (address instance) {
        deploymentName = toolkit.prefixWithChainName(block.chainid, deploymentName);
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
