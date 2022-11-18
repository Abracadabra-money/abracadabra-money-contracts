// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "cauldrons/CauldronV4.sol";
import "periphery/DegenBoxOwner.sol";

contract CauldronV4Script is BaseScript {
    function run() public returns (CauldronV4 masterContract, DegenBoxOwner degenBoxOwner) {
        vm.startBroadcast();

        if (block.chainid == ChainId.Mainnet) {
            masterContract = new CauldronV4(
                IBentoBoxV1(constants.getAddress("mainnet.degenBox")),
                IERC20(constants.getAddress("mainnet.mim"))
            );
        }

        if (block.chainid == ChainId.Arbitrum) {
            IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("arbitrum.degenBox"));
            masterContract = new CauldronV4(degenBox, IERC20(constants.getAddress("arbitrum.mim")));

            degenBoxOwner = new DegenBoxOwner();
            masterContract.transferOwnership(address(degenBoxOwner), true, false);
            degenBoxOwner.setDegenBox(degenBox);
        }

        if (!testing) {}

        vm.stopBroadcast();
    }
}
