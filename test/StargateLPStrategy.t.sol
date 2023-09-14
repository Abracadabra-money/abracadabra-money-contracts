// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/StargateLPStrategy.s.sol";

contract StargateLPStrategyTestBase is BaseTest {
    StargateLPStrategy strategy;
    IBentoBoxV1 box;
    IERC20 token;

    function initialize(uint256 chainId, uint256 blockNumber) public returns (StargateLPStrategyScript script) {
        fork(chainId, blockNumber);
        super.setUp();

        script = new StargateLPStrategyScript();
        script.setTesting(true);
    }

    function afterDeployed() public {
        box = IBentoBoxV1(strategy.bentoBox());
        token = IERC20(strategy.token());

        pushPrank(strategy.owner());
        box.setStrategy(token, trategy);
        popPrank();
    }

    function test() public {}
}

contract StargateLPStrategyTest is StargateLPStrategyTestBase {
    function setUp() public override {
        StargateLPStrategyScript script = super.initialize(ChainId.Kava, 6476735);
        (strategy) = script.deploy();
        super.afterDeployed();
    }
}
