// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";

contract GmxScript is BaseScript {
    struct Config {
        address degenBox;
        address masterContractV4;
        address glpManager;
    }

    mapping(uint256 => Config) configPerChainId;
    uint256[] configChaindIds;

    constructor() {
        configPerChainId[ChainId.Arbitrum] = Config({
            degenBox: constants.getAddress("arbitrum.degenBox"),
            masterContractV4: constants.getAddress("arbitrum.cauldronV4"),
            glpManager: constants.getAddress("arbitrum.gmx.glpManager")
        });
        configChaindIds.push(ChainId.Arbitrum);
    }

    function run() public {
        return;

        address xMerlin = constants.getAddress("xMerlin");

        vm.startBroadcast();

        Config storage config = configPerChainId[block.chainid];
        console2.log(config.degenBox);

        // Only when deploying live
        if (!testing) {
            //oracle.transferOwnership(xMerlin, true, false);
        }

        vm.stopBroadcast();
    }
}