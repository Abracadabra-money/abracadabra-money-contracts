// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "periphery/MarketLens.sol";

contract MarketLensScript is BaseScript {
    function run() public returns (MarketLens lens) {
        startBroadcast();

        lens = new MarketLens();

        stopBroadcast();
    }
}
