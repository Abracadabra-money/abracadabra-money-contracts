// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Vm, VmSafe} from "forge-std/Vm.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {UUPSUpgradeable} from "@solady/utils/UUPSUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {LibClone} from "@solady/utils/LibClone.sol";
import {Create3Factory} from "../src/mixins/Create3Factory.sol";
import {Toolkit, getToolkit, ChainId} from "utils/Toolkit.sol";
import {Deployer, DeployerDeployment} from "./Deployment.sol";
import {BlastMock} from "./mocks/BlastMock.sol";

abstract contract BaseScript is Script {
    Toolkit internal toolkit = getToolkit();

    function run() public virtual returns (DeployerDeployment[] memory newDeployments) {
        if (!testing() && block.chainid == ChainId.Blast) {
            vm.etch(address(0x4300000000000000000000000000000000000002), address(new BlastMock()).code);
            vm.allowCheatcodes(address(0x4300000000000000000000000000000000000002));
        }

        Address.functionDelegateCall(address(this), abi.encodeWithSignature("deploy()"));
        return toolkit.deployer().newDeployments();
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

    function deploy(string memory deploymentName, string memory artifact, bytes memory args) internal returns (address deployed) {
        Deployer deployer = toolkit.deployer();
        deploymentName = toolkit.prefixWithChainName(block.chainid, deploymentName);

        if (toolkit.testing()) {
            deployer.ignoreDeployment(deploymentName);
        }

        if (deployer.has(deploymentName)) {
            return deployer.getAddress(deploymentName);
        }

        bytes memory bytecode = vm.getCode(artifact);
        bytes memory data = bytes.concat(bytecode, args);

        assembly {
            deployed := create(0, add(data, 0x20), mload(data))
        }

        if (deployed == address(0)) {
            revert(string.concat("Failed to deploy ", deploymentName));
        }

        // No need to store anything in testing environment
        if (!toolkit.testing()) {
            (VmSafe.CallerMode callerMode, , ) = vm.readCallers();
            require(callerMode != VmSafe.CallerMode.Broadcast, "BaseScript: unexpected broadcast mode");
            if (callerMode == VmSafe.CallerMode.RecurrentBroadcast) {
                vm.stopBroadcast();
            }
            deployer.save(deploymentName, deployed, artifact, args, bytecode);
            if (callerMode == VmSafe.CallerMode.RecurrentBroadcast) {
                vm.startBroadcast();
            }
        } else {
            vm.label(deployed, deploymentName);
        }
    }

    function deployUsingCreate3(
        string memory deploymentName,
        bytes32 salt,
        string memory artifact,
        bytes memory args
    ) internal returns (address deployed) {
        return deployUsingCreate3(deploymentName, salt, artifact, args, 0);
    }

    function deployUsingCreate3(string memory deploymentName, bytes32 salt, bytes memory initcode) internal returns (address deployed) {
        return deployUsingCreate3(deploymentName, salt, "", initcode, 0);
    }

    function deployUsingCreate3(
        string memory deploymentName,
        bytes32 salt,
        bytes memory initcode,
        uint value
    ) internal returns (address deployed) {
        return deployUsingCreate3(deploymentName, salt, "", initcode, value);
    }

    function deployUsingCreate3(
        string memory deploymentName,
        bytes32 salt,
        string memory artifact,
        bytes memory args,
        uint value
    ) internal returns (address deployed) {
        Deployer deployer = toolkit.deployer();
        deploymentName = toolkit.prefixWithChainName(block.chainid, deploymentName);
        Create3Factory factory = Create3Factory(toolkit.getAddress("create3Factory"));

        /// In testing environment always ignore the current deployment and deploy the factory
        /// when it's not deployed on the current blockheight.
        if (testing()) {
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
        }

        bytes memory initcode;

        if (bytes(artifact).length != 0) {
            initcode = abi.encodePacked(vm.getCode(artifact), args);
        } else {
            initcode = args;
            args = "";
        }

        deployed = factory.deploy(salt, initcode, value);

        // No need to store anything in testing environment
        if (!toolkit.testing()) {
            // avoid sending this transaction live when using startBroadcast/stopBroadcast
            (VmSafe.CallerMode callerMode, , ) = vm.readCallers();
            if (callerMode == VmSafe.CallerMode.RecurrentBroadcast) {
                vm.stopBroadcast();
            }
            deployer.save(deploymentName, deployed, artifact, args, initcode);
            if (callerMode == VmSafe.CallerMode.RecurrentBroadcast) {
                vm.startBroadcast();
            }
        } else {
            vm.label(deployed, deploymentName);
        }
    }

    /// @dev The ERC-1967 storage slot for the implementation in the proxy
    /// uint256(keccak256("eip1967.proxy.implementation")) - 1`
    bytes32 internal constant ERC1967_IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @notice Deploys a new upgradeable contract implementing
    /// solady's UUPSUpgradeable and the associated proxy using create3.
    function deployUpgradeableUsingCreate3(
        string memory deploymentName,
        bytes32 salt,
        string memory artifact,
        bytes memory implementationArgs,
        bytes memory initializerCallArgs
    ) internal returns (address deployed) {
        address implementation = deploy(string.concat(deploymentName, "Impl"), artifact, implementationArgs);

        // call proxiableUUID on the immplementation to be sure it's implementing UUPSUpgradeable
        if (UUPSUpgradeable(implementation).proxiableUUID() != ERC1967_IMPLEMENTATION_SLOT) {
            revert("implementation does not implement UUPSUpgradeable");
        }

        deployed = deployUsingCreate3(deploymentName, salt, LibClone.initCodeERC1967(implementation));
        Address.functionCall(deployed, initializerCallArgs);
    }

    /// @notice Generates a salt for ERC1967Factory
    /// The upper 160 bits are the deployer address, and the lower 96 bits are the keccak256 hash of the label
    function generateERC1967FactorySalt(address deployer, bytes memory label) internal pure returns (bytes32) {
        return bytes32((uint256(uint160(deployer)) << 96) | (uint256(keccak256(abi.encodePacked(label))) >> 160));
    }
}
