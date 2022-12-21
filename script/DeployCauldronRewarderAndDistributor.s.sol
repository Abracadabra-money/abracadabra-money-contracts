// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "script/CauldronRewarder.s.sol";
import "script/CauldronV4WithRewarder.s.sol";
import "script/MimCauldronDistributorV4.s.sol";
import "forge-std/console.sol";


contract DeployCauldronRewarderAndDistributorScript is BaseScript {
    function run() public {
        if (block.chainid == ChainId.Arbitrum) {

            CauldronV4WithRewarderScript script = new CauldronV4WithRewarderScript();
            
            (CauldronV4WithRewarder masterContract, CauldronV4WithRewarder cauldron) = script.run();

            CauldronRewarderScript script2 = new CauldronRewarderScript();

            console.log(address(cauldron), address(masterContract));

            script2.setCauldron(ICauldronV4(address(cauldron)));

            script2.run();
            //IRewarder rewarder = IRewarder(address());

            /*startBroadcast();

            cauldron.setRewarder(rewarder);

            stopBroadcast(); 

            MimCauldronDistributorScript script3 = new MimCauldronDistributorScript();

            script3.setCauldronAndRewarder(ICauldronV4(address(cauldron)), rewarder);

            script3.run(); */
            
        }
    }
}
