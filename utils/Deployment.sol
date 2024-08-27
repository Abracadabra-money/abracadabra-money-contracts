// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from "../lib/forge-std/src/Vm.sol";
import "../lib/forge-std/src/StdJson.sol";

struct DeployerDeployment {
    string name;
    address payable addr;
    bytes bytecode;
    bytes args;
    string artifact;
}

struct Deployment {
    address payable addr;
    bytes bytecode;
    bytes args;
}

/// @notice contract that keep track of the deployment and save them as return value in the forge's broadcast
/// @author Adapted from https://github.com/wighawag/forge-deploy
contract Deployer {
    Vm constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    mapping(string => DeployerDeployment) internal _namedDeployments;
    DeployerDeployment[] internal _newDeployments;

    /// @notice function that return all new deployments as an array
    function newDeployments() external view returns (DeployerDeployment[] memory) {
        return _newDeployments;
    }

    /// @notice function that tell you whether a deployment already exists with that name
    /// @param name deployment's name to query
    /// @return exists whether the deployment exists or not
    function has(string memory name) public view returns (bool exists) {
        DeployerDeployment memory existing = _namedDeployments[name];

        if (existing.addr != address(0)) {
            if (bytes(existing.name).length == 0) {
                return false;
            }
            return true;
        }

        return _getExistingDeploymentAdress(name) != address(0);
    }

    /// @notice function that return the address of a deployment
    /// @param name deployment's name to query
    /// @return addr the deployment's address or the zero address
    function getAddress(string memory name) public view returns (address payable addr) {
        DeployerDeployment memory existing = _namedDeployments[name];

        if (existing.addr != address(0)) {
            if (bytes(existing.name).length == 0) {
                return payable(address(0));
            }
            return existing.addr;
        }

        return _getExistingDeploymentAdress(name);
    }

    /// @notice allow to override an existing deployment by ignoring the current one.
    /// the deployment will only be overriden on disk once the broadast is performed and `forge-deploy` sync is invoked.
    /// @param name deployment's name to override
    function ignoreDeployment(string memory name) public {
        _namedDeployments[name].name = "";
        _namedDeployments[name].addr = payable(address(1)); // TO ensure it is picked up as being ignored
    }

    /// @notice function that return the deployment (address, bytecode and args bytes used)
    /// @param name deployment's name to query
    /// @return deployment the deployment (with address zero if not existent)
    function get(string memory name) public view returns (Deployment memory deployment) {
        DeployerDeployment memory newDeployment = _namedDeployments[name];

        if (newDeployment.addr != address(0)) {
            if (bytes(newDeployment.name).length > 0) {
                deployment.addr = newDeployment.addr;
                deployment.bytecode = newDeployment.bytecode;
                deployment.args = newDeployment.args;
            }
        } else {
            deployment = _getExistingDeployment(name);
        }
    }

    /// @notice save the deployment info under the name provided
    /// @param name deployment's name
    /// @param deployed address of the deployed contract
    /// @param artifact forge's artifact path <solidity file>.sol:<contract name>
    /// @param args arguments' bytes provided to the constructor
    /// @param bytecode the contract's bytecode used to deploy the contract
    function save(string memory name, address deployed, string memory artifact, bytes memory args, bytes memory bytecode) public {
        require(bytes(name).length > 0, "EMPTY_NAME_NOT_ALLOWED");

        DeployerDeployment memory deployment = DeployerDeployment({
            name: name,
            addr: payable(address(deployed)),
            bytecode: bytecode,
            args: args,
            artifact: artifact
        });
        _namedDeployments[name] = deployment;
        _newDeployments.push(deployment);
    }
    
    function _getExistingDeploymentAdress(string memory name) internal view returns (address payable) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", vm.toString(block.chainid), "/", name, ".json");

        try vm.readFile(path) returns (string memory json) {
            bytes memory addr = stdJson.parseRaw(json, ".address");
            return abi.decode(addr, (address));
        } catch {
            return payable(address(0));
        }
    }

    function _getExistingDeployment(string memory name) internal view returns (Deployment memory deployment) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", vm.toString(block.chainid), "/", name, ".json");

        try vm.readFile(path) returns (string memory json) {
            bytes memory addrBytes = stdJson.parseRaw(json, ".address");
            bytes memory bytecodeBytes = stdJson.parseRaw(json, ".bytecode");
            bytes memory argsBytes = stdJson.parseRaw(json, ".args_data");
            deployment.addr = abi.decode(addrBytes, (address));
            deployment.bytecode = abi.decode(bytecodeBytes, (bytes));
            deployment.args = abi.decode(argsBytes, (bytes));
        } catch {}
    }
}
