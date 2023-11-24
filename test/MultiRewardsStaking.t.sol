// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MultiRewardsStaking.s.sol";

contract MultiRewardsStakingTest is BaseTest {
    MultiRewardsStaking staking;

    function setUp() public override {
        fork(ChainId.Arbitrum, 153716876);
        super.setUp();

        MultiRewardsStakingScript script = new MultiRewardsStakingScript();
        script.setTesting(true);

        (staking) = script.deploy();
    }

    function test() public {
        
    }
 }
