// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "periphery/MagicApeLens.sol";

contract MagicApeLensScript is BaseScript {
    function run() public returns (MagicApeLens lens) {
        startBroadcast();

        lens = new MagicApeLens();

        stopBroadcast();
    }
}