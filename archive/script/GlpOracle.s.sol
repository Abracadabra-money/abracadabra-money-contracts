// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "oracles/ProxyOracle.sol";
import "oracles/GLPOracle.sol";

contract GlpOracleScript is BaseScript {

    struct Config {
        address glp;
        address safe;
        address glpManager;
    }

    mapping(uint256 => Config) configPerChainId;
    uint256[] configChaindIds;

    constructor() {
        configPerChainId[ChainId.Arbitrum] = Config({
            glp: constants.getAddress("arbitrum.gmx.glp"),
            safe: constants.getAddress("arbitrum.safe.main"),
            glpManager: constants.getAddress("arbitrum.gmx.glpManager")
        });
        configChaindIds.push(ChainId.Arbitrum);
    }
    function run() public returns (ProxyOracle proxy) {
        vm.startBroadcast();

        // Deployment here.

        proxy = new ProxyOracle();
        
        Config storage config = configPerChainId[block.chainid];
        GLPOracle oracle = new GLPOracle(IGmxGlpManager(config.glpManager), IERC20(config.glp));
        
        proxy.changeOracleImplementation(IOracle(oracle));

        if (!testing) {
            proxy.transferOwnership(config.safe, true, false);
        }
        
        vm.stopBroadcast();
    }
}
