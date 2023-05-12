// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/LegacyBaseScript.sol";
import "lenses/MarketLens.sol";

contract MarketLensScript is LegacyBaseScript {
    function run() public returns (MarketLens lens) {
        startBroadcast();

        lens = new MarketLens{salt: bytes32(bytes("MarketLens.s.sol-20230406-v6"))}();

        stopBroadcast();
    }
}
