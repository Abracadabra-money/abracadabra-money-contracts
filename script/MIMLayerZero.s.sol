// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "generated/abra-layerzero/deployer/DeployerFunctions.g.sol";
import "abracadabra-layerzero/token/oft/v2/IndirectOFTV2.sol";

contract MIMLayerZeroScript is BaseScript {
    using DeployerFunctions for Deployer;

    function deploy() public {
        if (block.chainid == ChainId.Mainnet) {}

        if (block.chainid == ChainId.BSC) {
            deployer.deploy_IndirectOFTV2("BSC_IndirectOFTV2", address(0), 0, address(0));
        }
        if (block.chainid == ChainId.Polygon) {
            deployer.deploy_IndirectOFTV2("Polygon_IndirectOFTV2", address(0), 0, address(0));
        }
        if (block.chainid == ChainId.Fantom) {
            deployer.deploy_IndirectOFTV2("Fantom_IndirectOFTV2", address(0), 0, address(0));
        }
        if (block.chainid == ChainId.Optimism) {
            deployer.deploy_IndirectOFTV2("Optimism_IndirectOFTV2", address(0), 0, address(0));
        }
        if (block.chainid == ChainId.Arbitrum) {
            deployer.deploy_IndirectOFTV2("Arbitrum_IndirectOFTV2", address(0), 0, address(0));
        }
        if (block.chainid == ChainId.Avalanche) {
            deployer.deploy_IndirectOFTV2("Avalanche_IndirectOFTV2", address(0), 0, address(0));
        }
    }
}
