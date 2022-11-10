// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "oracles/ProxyOracle.sol";
import "utils/BaseScript.sol";
import "utils/CauldronLib.sol";
import "periphery/CauldronOwner.sol";

contract CauldronOwnerScript is BaseScript {
    function run() public returns (CauldronOwner owner) {
        ERC20 mim = ERC20(constants.getAddress("mainnet.mim"));
        address treasury = constants.getAddress("mainnet.mimTreasury");
        address xMerlin = constants.getAddress("xMerlin");

        vm.startBroadcast();

        owner = new CauldronOwner(treasury, mim);

        if (!testing) {
            owner.transferOwnership(xMerlin, true, false);
        }

        vm.stopBroadcast();
    }
}
