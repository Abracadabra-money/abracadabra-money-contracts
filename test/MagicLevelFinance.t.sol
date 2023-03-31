// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./mixins/MagicLevelFinanceBase.sol";

contract MagicLevelFinanceJuniorVault is MagicLevelFinanceTestBase {
    function setUp() public override {
        super.initialize(921051199533511162 /* expected oracle price */, 0xAcE3371545521BA5Bb1Bd1555d360C680e835eb0);
        (oracle, , , vault, , , harvestor) = script.run();
        super.afterInitialize();
    }
}

contract MagicLevelFinanceMezzanineVault is MagicLevelFinanceTestBase {
    function setUp() public override {
        super.initialize(971790522869011181 /* expected oracle price */, 0xD804Ea7306abE2456Bdd04a31F6f6a2F55Dc0d21);
        (, oracle, , , vault, , harvestor) = script.run();
        super.afterInitialize();
    }
}

contract MagicLevelFinanceSeniorVault is MagicLevelFinanceTestBase {
    function setUp() public override {
        super.initialize(809214587157509035 /* expected oracle price */, 0x8BFf27E9Fa1C28934554e6B5239Fb52776573619);
        (, , oracle, , , vault, harvestor) = script.run();
        super.afterInitialize();
    }
}
