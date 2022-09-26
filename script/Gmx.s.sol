// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "utils/GmxLib.sol";

contract GmxScript is BaseScript {
    struct Config {
        address degenBox;
        address glpManager;
    }

    mapping(uint256 => Config) configPerChainId;
    uint256[] configChaindIds;

    constructor() {
        configPerChainId[ChainId.Arbitrum] = Config({
            degenBox: constants.getAddress("arbitrum.degenBox"),
            glpManager: constants.getAddress("arbitrum.gmx.glpManager")
        });
        configChaindIds.push(ChainId.Arbitrum);
    }

    function run() public returns (ProxyOracle oracle) {
        address xMerlin = constants.getAddress("xMerlin");

        vm.startBroadcast();

        Config storage config = configPerChainId[block.chainid];
        console2.log(config.degenBox);

        // Only when deploying live
        if (!testing) {
            oracle.transferOwnership(xMerlin, true, false);
        }

        vm.stopBroadcast();
    }
}
