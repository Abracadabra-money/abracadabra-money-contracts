// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Deployer.sol";

struct DeployOptions {
    uint256 salt;
}

struct PrivateDeployOptions {
    bool deterministic;
    uint256 salt;
}

library DefaultDeployerFunction {
    function prepareCall(Deployer deployer) internal {
        prepareCall(deployer, address(0));
    }

    function prepareCall(Deployer deployer, address sender) internal {
        (bool prankActive, address prankAddress) = deployer.prankStatus();
        bool autoBroadcast = deployer.autoBroadcasting();
        if (prankActive) {
            if (prankAddress != address(0)) {
                vm.prank(prankAddress);
            } else {
                vm.prank(sender);
            }
        } else if (autoBroadcast) {
            if (sender != address(0)) {
                vm.broadcast(sender);
            } else {
                vm.broadcast();
            }
        }
    }

    /// @notice generic deploy function (to be used with Deployer)
    ///  `using DefaultDeployerFunction with Deployer;`
    /// @param deployer contract that keep track of the deployments and save them
    /// @param name the deployment's name that will stored on disk in `<deployments>/<context>/<name>.json`
    /// @param artifact forge's artifact path `<solidity file>.sol:<contract name>`
    /// @param args encoded arguments for the contract's constructor
    function deploy(
        Deployer deployer,
        string memory name,
        string memory artifact,
        bytes memory args
    ) internal returns (address payable deployed) {
        return _deploy(deployer, name, artifact, args, PrivateDeployOptions({deterministic: false, salt: 0}));
    }

    /// @notice generic create2 deploy function (to be used with Deployer)
    ///  `using DefaultDeployerFunction with Deployer;`
    /// @param deployer contract that keep track of the deployments and save them
    /// @param name the deployment's name that will stored on disk in `<deployments>/<context>/<name>.json`
    /// @param artifact forge's artifact path `<solidity file>.sol:<contract name>`
    /// @param args encoded arguments for the contract's constructor
    /// @param options options to specify for salt for deterministic deployment
    function deploy(
        Deployer deployer,
        string memory name,
        string memory artifact,
        bytes memory args,
        DeployOptions memory options
    ) internal returns (address payable deployed) {
        return _deploy(deployer, name, artifact, args, PrivateDeployOptions({deterministic: true, salt: options.salt}));
    }

    // --------------------------------------------------------------------------------------------
    // PRIVATE
    // --------------------------------------------------------------------------------------------
    Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    function _deploy(
        Deployer deployer,
        string memory name,
        string memory artifact,
        bytes memory args,
        PrivateDeployOptions memory options
    ) private returns (address payable deployed) {
        address payable existing = deployer.getAddress(name);
        if (existing == address(0)) {
            bytes memory bytecode = vm.getCode(artifact);
            bytes memory data = bytes.concat(bytecode, args);
            if (options.deterministic) {
                uint256 salt = options.salt;
                prepareCall(deployer);
                assembly {
                    deployed := create2(0, add(data, 0x20), mload(data), salt)
                }
            } else {
                prepareCall(deployer);
                assembly {
                    deployed := create(0, add(data, 0x20), mload(data))
                }
            }

            if (deployed == address(0)) {
                revert(string.concat("Failed to deploy ", name));
            }
            deployer.save(name, deployed, artifact, args, bytecode);
        } else {
            deployed = existing;
        }
    }
}
