// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/Liquity.s.sol";

contract LiquityTest is BaseTest {
    ProxyOracle public oracle;
    ISwapperV2 public swapper;
    ILevSwapperV2 public levSwapper;

    function setUp() public override {
        super.setUp();

        forkMainnet(15424234);
        initConfig();

        LiquityScript script = new LiquityScript();
        script.setTesting(true);
        (oracle, swapper, levSwapper) = script.run();
    }

    function testOracle() public {
        assertEq(oracle.peekSpot(""), 967679925929907749); // around $1.02
    }
}
