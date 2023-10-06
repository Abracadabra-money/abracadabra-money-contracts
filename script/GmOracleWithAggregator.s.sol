// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "oracles/GmOracleWithAggregator.sol";

contract GmOracleWithAggregatorScript is BaseScript {

    function deploy() public returns (GmOracleWithAggregator oracle) {
        if (block.chainid == ChainId.Arbitrum) {
            vm.startBroadcast();

            oracle = new GmOracleWithAggregator(
                IGmxReader("arbitrum.gmx.v2.reader"),
                IAggregator(toolkit.getAddress("arbitrum.chainlink.eth")),
                IAggregator(toolkit.getAddress("arbitrum.chainlink.usdc")),
                toolkit.getAddress("arbitrum.gmx.v2.gmETH"),
                toolkit.getAddress("arbitrum.gmx.v2.dataStore"),
                "gmETH/USD"
            );

            vm.stopBroadcast();
        } else {
            revert("chain not supported");
        }
    }
}
