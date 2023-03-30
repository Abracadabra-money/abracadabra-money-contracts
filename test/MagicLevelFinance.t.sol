// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./mixins/MagicLevelFinanceBase.sol";

contract MagicLevelFinanceJuniorVault is MagicLevelFinanceTestBase {
    function setUp() public override {
        super.initialize(917346051470049172 /* expected oracle price */);
        (oracle, , , vault, , ) = script.run();
    }
}

contract MagicLevelFinanceMezzanineVault is MagicLevelFinanceTestBase {
    function setUp() public override {
        super.initialize(965843320306198540 /* expected oracle price */);
        (, oracle, , , vault, ) = script.run();
    }
}

contract MagicLevelFinanceSeniorVault is MagicLevelFinanceTestBase {
    function setUp() public override {
        super.initialize(801799363881478307 /* expected oracle price */);
        (, , oracle, , , vault) = script.run();
    }
}
