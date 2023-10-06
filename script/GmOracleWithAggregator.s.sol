// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "oracles/GmOracleWithAggregator.sol";

contract GmOracleWithAggregatorScript is BaseScript {
    mapping (string => uint256) public oraclePrecision;

    constructor() {
        oraclePrecision["USDC"] = 24;
        oraclePrecision["ETH"] = 12;
    }
    function deploy() public returns (GmOracleWithAggregator oracle) {
        if (block.chainid == ChainId.Arbitrum) {
            vm.startBroadcast();

            uint256 expansionFactorIndex = 10**(oraclePrecision["ETH"] -  IAggregator(toolkit.getAddress("arbitrum.chainlink.eth")).decimals());
            uint256 expansionFactorShort = 10**(oraclePrecision["USDC"] - IAggregator(toolkit.getAddress("arbitrum.chainlink.usdc")).decimals());

            oracle = new GmOracleWithAggregator(
                IGmxReader(0xf60becbba223EEA9495Da3f606753867eC10d139),
                IAggregator(toolkit.getAddress("arbitrum.chainlink.eth")),
                IAggregator(toolkit.getAddress("arbitrum.chainlink.usdc")),
                expansionFactorIndex,
                expansionFactorShort,
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
