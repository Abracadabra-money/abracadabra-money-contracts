// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "periphery/MimCauldronDistributor.sol";
import "utils/CauldronLib.sol";

contract MimCauldronDistributorScript is BaseScript {
    ICauldronV4 cauldron;
    IRewarder rewarder;

    function setCauldronAndRewarder(ICauldronV4 cauldron_, IRewarder rewarder_) external {
        cauldron = cauldron_;
        rewarder = rewarder_;
    }

    function run() public returns (MimCauldronDistributor distributor) {
        
        if (block.chainid == ChainId.Arbitrum) {
            address safe = constants.getAddress("arbitrum.safe.ops");
            ERC20 mim = ERC20(constants.getAddress("arbitrum.mim"));
            
            startBroadcast();

            distributor = new MimCauldronDistributor(mim, safe, CauldronLib.getInterestPerSecond(1000));

            if (!testing) {
                // GLP cauldron 10% target apy, up to 
                distributor.setCauldronParameters(cauldron, 1000, 1000 ether, rewarder);
                distributor.transferOwnership(safe, true, false);
            }
            
            stopBroadcast();
        }
    }
}
