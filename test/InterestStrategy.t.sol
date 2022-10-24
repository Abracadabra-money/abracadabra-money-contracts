// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/InterestStrategy.s.sol";

contract MyTest is BaseTest {
    InterestStrategy public strategy;

    function setUp() public override {
        forkMainnet(15819653);
        super.setUp();

        InterestStrategyScript script = new InterestStrategyScript();
        script.setTesting(true);
        (strategy) = script.run();
    }

    function test() public {
        
    }
}
