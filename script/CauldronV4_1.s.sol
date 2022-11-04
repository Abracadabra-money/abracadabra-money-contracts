// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "cauldrons/CauldronV4_1.sol";

contract CauldronV4_1Script is BaseScript {
    function run() public returns (CauldronV4_1 masterContract) {
        vm.startBroadcast();

        masterContract = new CauldronV4_1(
            IBentoBoxV1(constants.getAddress("mainnet.degenBox")),
            IERC20(constants.getAddress("mainnet.mim"))
        );

        // Only when deploying live
        if (!testing) {}

        vm.stopBroadcast();
    }
}
