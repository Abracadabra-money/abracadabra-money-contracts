// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "periphery/MimCauldronDistributor.sol";

contract MimCauldronDistributorScript is BaseScript {
    function run() public returns (MimCauldronDistributor distributor) {
        if (block.chainid == ChainId.Arbitrum) {
            address safe = constants.getAddress("arbitrum.safe.ops");
            ERC20 mim = ERC20(constants.getAddress("arbitrum.mim"));

            vm.startBroadcast();

            distributor = new MimCauldronDistributor(mim);

            if (!testing) {
                distributor.transferOwnership(safe, true, false);
            }

            vm.stopBroadcast();
        }
    }
}
