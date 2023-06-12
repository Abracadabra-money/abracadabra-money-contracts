// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-deploy/DeployScript.sol";
import "generated/deployer/DeployerFunctions.g.sol";
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

    function signer() internal view returns (address) {
        return testing ? address(this) : tx.origin;
    }
}