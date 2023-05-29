// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "cauldrons/CauldronV4.sol";
import "utils/CauldronDeployLib.sol";
import "oracles/ProxyOracle.sol";
import "periphery/CauldronOwner.sol";
import "interfaces/IGmxRewardRouterV2.sol";
import "tokens/GmxGlpWrapper.sol";
import "periphery/GmxGlpRewardHandler.sol";
import "periphery/MimCauldronDistributor.sol";
import "periphery/DegenBoxTokenWrapper.sol";
import "periphery/GlpWrapperHarvestor.sol";

contract GlpCauldronScript is BaseScript {
    function deploy() public {
        vm.startBroadcast();

        if (block.chainid == ChainId.Arbitrum) {
            CauldronOwner cauldronOwner = new CauldronOwner(
                constants.getAddress("arbitrum.safe.ops"),
                ERC20(address(IERC20(constants.getAddress("arbitrum.mim"))))
            );

            // Only when deploying live
            if (!testing) {
                cauldronOwner.setOperator(constants.getAddress("arbitrum.safe.ops"), true);
                cauldronOwner.transferOwnership(constants.getAddress("arbitrum.safe.ops"), true, false);
            }
        } else {
            revert("chain not supported");
        }

        vm.stopBroadcast();
    }
}
