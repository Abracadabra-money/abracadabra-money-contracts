// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./mixins/MagicLevelFinanceBase.sol";

contract MagicLevelFinanceJuniorVault is MagicLevelFinanceTestBase {
    function setUp() public override {
        super.initialize(921051199533511162 /* expected oracle price */);
        (oracle, , , vault, , , harvestor) = script.run();
        super.afterInitialize();
    }
}

//contract MagicLevelFinanceMezzanineVault is MagicLevelFinanceTestBase {
//    function setUp() public override {
//        super.initialize(971790522869011181 /* expected oracle price */);
//        (, oracle, , , vault, , harvestor) = script.run();
//        super.afterInitialize();
//    }
//}
//
//contract MagicLevelFinanceSeniorVault is MagicLevelFinanceTestBase {
//    function setUp() public override {
//        super.initialize(809214587157509035 /* expected oracle price */);
//        (, , oracle, , , vault, harvestor) = script.run();
//        super.afterInitialize();
//    }
//}
