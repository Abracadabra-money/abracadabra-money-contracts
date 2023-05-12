// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/Constants.sol";

/// @dev This is a legacy version of BaseScript that is compatible with the script
/// prior to the introduction of the forge-deploy library
abstract contract LegacyBaseScript is Script {
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
}