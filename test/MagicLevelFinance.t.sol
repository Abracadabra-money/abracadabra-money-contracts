// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MagicLevelFinance.s.sol";

contract MagicLevelFinanceTest is BaseTest {
    ProxyOracle magicLVLJuniorOracle;
    ProxyOracle magicLVLMezzanineOracle;
    ProxyOracle magicLVLSeniorOracle;
    MagicLevel magicLVLJunior;
    MagicLevel magicLVLMezzanine;
    MagicLevel magicLVLSenior;

    function setUp() public override {
        forkBSC(15371985);
        super.setUp();

        MagicLevelFinanceScript script = new MagicLevelFinanceScript();
        script.setTesting(true);
        (magicLVLJuniorOracle, magicLVLMezzanineOracle, magicLVLSeniorOracle, magicLVLJunior, magicLVLMezzanine, magicLVLSenior) = script
            .run();
    }

    function test() public {
        console2.log(magicLVLJuniorOracle.peekSpot(""));
    }
}
