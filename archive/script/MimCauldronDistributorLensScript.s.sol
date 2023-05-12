// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "interfaces/IGlpWrapperHarvestor.sol";
import "periphery/MimCauldronDistributorLens.sol";

contract MimCauldronDistributorLensScript is BaseScript {
    function deploy() public {
        vm.startBroadcast();

        if (block.chainid == ChainId.Arbitrum) {
            new MimCauldronDistributorLens(IGlpWrapperHarvestor(0xf9cE23237B25E81963b500781FA15d6D38A0DE62)); // using harvester v2
        }

        vm.stopBroadcast();
    }
}
