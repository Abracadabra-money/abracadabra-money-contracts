// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {BaseScript} from "utils/BaseScript.sol";
import {MagicLPLens} from "lenses/MagicLPLens.sol";

contract MagicLPLensScript is BaseScript {
    // CREATE3 salts
    bytes32 constant MAGIC_LP_LENS_SALT = keccak256(bytes("MagicLPLens-v1"));

    function deploy() public returns (MagicLPLens lens) {
        vm.startBroadcast();
        lens = MagicLPLens(deployUsingCreate3("MagicLPLens", MAGIC_LP_LENS_SALT, "MagicLPLens.sol:MagicLPLens", "", 0));
        vm.stopBroadcast();
    }
}
