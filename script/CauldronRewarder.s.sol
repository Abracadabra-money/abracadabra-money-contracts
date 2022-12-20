// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "periphery/CauldronRewarder.sol";

contract CauldronRewarderScript is BaseScript {
    function run() public returns (CauldronRewarder rewarder) {
        if (block.chainid == ChainId.Arbitrum) { 
            ICauldronV4 cauldron = ICauldronV4(0xdCA1514b98bec62aBA0610f23F579F36c79e6ed2);
            IERC20 mim = IERC20(constants.getAddress("arbitrum.mim"));

            startBroadcast();

            rewarder = new CauldronRewarder(mim, cauldron);

            stopBroadcast();
            
        }
    }
    function run(ICauldronV4 cauldron) public returns (CauldronRewarder rewarder) {
        if (block.chainid == ChainId.Arbitrum) {
            IERC20 mim = IERC20(constants.getAddress("arbitrum.mim"));

            startBroadcast();

            rewarder = new CauldronRewarder(mim, cauldron);

            stopBroadcast();
        }
    }
}
