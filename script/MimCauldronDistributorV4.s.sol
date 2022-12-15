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

            vm.startBroadcast();

            distributor = new MimCauldronDistributor(mim, safe, CauldronLib.getInterestPerSecond(1000));

            if (!testing) {
                // GLP cauldron 10% target apy, up to 
                //distributor.setCauldronParameters(ICauldronV4(0x5698135CA439f21a57bDdbe8b582C62f090406D5), 1000, 1000 ether);
                distributor.transferOwnership(safe, true, false);
            }

            vm.stopBroadcast();
        }
    }
}
