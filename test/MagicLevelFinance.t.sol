// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./mixins/MagicLevelFinanceBase.sol";

contract MagicLevelFinanceJuniorVault is MagicLevelFinanceTestBase {
    function setUp() public override {
        super.initialize(917346051470049172 /* expected oracle price */);
        (oracle, , , vault, , ) = script.run();

        console2.log("MagicLevelAddress", address(vault));
        console2.log("sender", address(this));
        console2.log("tx.origin", address(tx.origin));
        console2.log("msg.sender", address(msg.sender));
    }
}

//ontract MagicLevelFinanceMezzanineVault is MagicLevelFinanceTestBase {
//   function setUp() public override {
//       super.initialize(965843320306198540 /* expected oracle price */);
//       (, oracle, , , vault, ) = script.run();
//   }
//
//
//ontract MagicLevelFinanceSeniorVault is MagicLevelFinanceTestBase {
//   function setUp() public override {
//       super.initialize(801799363881478307 /* expected oracle price */);
//       (, , oracle, , , vault) = script.run();
//   }
//
