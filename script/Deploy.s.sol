// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "utils/OracleLib.sol";

contract MyScript is BaseScript {
    function run() public {
        startBroadcast();

        // USDT/ETH -> ETH/USD
        OracleLib.deploySimpleInvertedOracle("TEST/USD", IAggregator(0xee9f2375b4bdf6387aa8265dd4fb8f16512a1d46));
        
        stopBroadcast();
    }
}
