// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "periphery/MagicApeLens.sol";

contract MagicAPELensScript is BaseScript {
    function deploy() public returns (MagicAPELens lens) {
        vm.startBroadcast();

        lens = new MagicAPELens{salt: bytes32(bytes("MagicAPELens-v1"))}();

        vm.stopBroadcast();
    }
}
