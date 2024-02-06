// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {BaseScript, ChainId} from "utils/BaseScript.sol";
import {ICauldronV2} from "interfaces/ICauldronV2.sol";
import {OracleUpdater} from "periphery/OracleUpdater.sol";
import {CauldronRegistry} from "periphery/CauldronRegistry.sol";
import {MasterContractConfigurationRegistry} from "periphery/MasterContractConfigurationRegistry.sol";

contract OracleUpdaterScript is BaseScript {
    function deploy()
        public
        returns (
            OracleUpdater oracleUpdater,
            CauldronRegistry cauldronRegistry,
            MasterContractConfigurationRegistry masterContractConfigurationRegistry
        )
    {
        require(block.chainid == ChainId.Mainnet, "Wrong chain");

        vm.startBroadcast();
        cauldronRegistry = CauldronRegistry(deploy("CauldronRegistry", "CauldronRegistry.sol:CauldronRegistry", abi.encode(tx.origin)));

        masterContractConfigurationRegistry = MasterContractConfigurationRegistry(
            deploy(
                "MasterContractConfigurationRegistry",
                "MasterContractConfigurationRegistry.sol:MasterContractConfigurationRegistry",
                abi.encode(tx.origin)
            )
        );

        oracleUpdater = OracleUpdater(
            deploy("OracleUpdater", "OracleUpdater.sol:OracleUpdater", abi.encode(cauldronRegistry, masterContractConfigurationRegistry))
        );
        vm.stopBroadcast();
    }
}
