// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "periphery/CauldronRewarder.sol";

contract CauldronRewarderScript is BaseScript {
    ICauldronV4 cauldron;

    function setCauldron(ICauldronV4 _cauldron) external {
        cauldron = _cauldron;
    }

    function deploy() public returns (CauldronRewarder rewarder) {
        if (block.chainid == ChainId.Arbitrum) {
            IERC20 mim = IERC20(constants.getAddress("arbitrum.mim"));
            startBroadcast();
            rewarder = new CauldronRewarder(mim, cauldron);
            stopBroadcast();
        }
    }

    function deploy(ICauldronV4 _cauldron) public returns (CauldronRewarder rewarder) {
        if (block.chainid == ChainId.Arbitrum) {
            IERC20 mim = IERC20(constants.getAddress("arbitrum.mim"));
            startBroadcast();
            rewarder = new CauldronRewarder(mim, _cauldron);
            stopBroadcast();
        }
    }
}
