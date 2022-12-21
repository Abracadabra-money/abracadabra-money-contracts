// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "script/CauldronRewarder.s.sol";
import "script/CauldronV4WithRewarder.s.sol";
import "script/MimCauldronDistributorV4.s.sol";

contract DeployCauldronRewarderAndDistributor is BaseScript {
    function run() public {
        if (block.chainid == ChainId.Arbitrum) {
            startBroadcast();

            CauldronV4WithRewarderScript script = new CauldronV4WithRewarderScript();
            (CauldronV4WithRewarder masterContract, CauldronV4WithRewarder cauldron) = script.run();

            CauldronRewarderScript script2 = new CauldronRewarderScript();

            IRewarder rewarder = IRewarder(address(script2.run(ICauldronV4(address(cauldron)))));

            cauldron.setRewarder(rewarder);

            MimCauldronDistributorScript script3 = new MimCauldronDistributorScript();

            script3.setCauldronAndRewarder(ICauldronV4(address(cauldron)), rewarder);

            script3.run();

            stopBroadcast();
        }
    }
}
