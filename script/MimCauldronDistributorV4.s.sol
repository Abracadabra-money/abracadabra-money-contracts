// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "periphery/MimCauldronDistributor.sol";
import "utils/CauldronLib.sol";

contract MimCauldronDistributorScript is BaseScript {
    function run() public returns (MimCauldronDistributor distributor) {
        
        if (block.chainid == ChainId.Arbitrum) {
            address safe = constants.getAddress("arbitrum.safe.ops");
            ERC20 mim = ERC20(constants.getAddress("arbitrum.mim"));

            startBroadcast();

            distributor = new MimCauldronDistributor(mim, safe, CauldronLib.getInterestPerSecond(1000));

            if (!testing) {
                // GLP cauldron 10% target apy, up to 
                distributor.setCauldronParameters(ICauldronV4(0xdCA1514b98bec62aBA0610f23F579F36c79e6ed2), 1000, 1000 ether, IRewarder(0x3BAB7207D4E27b5DE4A15D540B7297281B45Ed2a));
                distributor.transferOwnership(safe, true, false);
            }

            stopBroadcast();
        }
    }
}
