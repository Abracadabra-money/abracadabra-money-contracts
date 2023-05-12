// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/LegacyBaseScript.sol";
import "periphery/MagicApeLens.sol";

contract MagicAPELensScript is LegacyBaseScript {
    function run() public returns (MagicAPELens lens) {
        startBroadcast();

        lens = new MagicAPELens{salt: bytes32(bytes("MagicAPELens-v1"))}();

        stopBroadcast();
    }
}
