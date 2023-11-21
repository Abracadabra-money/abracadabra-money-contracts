// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "lenses/MarketLens.sol";
import "mixins/Create3Factory.sol";

contract MarketLensScript is BaseScript {
    // CREATE3 salts
    bytes32 constant MARKET_LENS_SALT = keccak256(bytes("MarketLens-v7"));

    function deploy() public returns (MarketLens lens) {
        vm.startBroadcast();
        lens = MarketLens(deployUsingCreate3("MarketLens", MARKET_LENS_SALT, "MarketLens.sol:MarketLens", "", 0));
        vm.stopBroadcast();
    }
}
