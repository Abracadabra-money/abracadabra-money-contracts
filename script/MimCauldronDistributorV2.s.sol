// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "interfaces/ICauldronV4.sol";
import "periphery/MimCauldronDistributor.sol";

contract MimCauldronDistributorV2Script is BaseScript {
    function run() public returns (MimCauldronDistributor distributorV2) {
        address safe = constants.getAddress("arbitrum.safe.ops");
        address mim = constants.getAddress("arbitrum.mim");

        vm.startBroadcast();

        distributorV2 = new MimCauldronDistributor(ERC20(mim), ICauldronV4(0xE09223bBdb85a20111DCD72299142a8626d5eA4b));

        if (!testing) {
            distributorV2.transferOwnership(safe, true, false);
        }

        vm.stopBroadcast();
    }
}
