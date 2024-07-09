// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/RewardDistributors.s.sol";

contract RewardDistributorsTest is BaseTest {
    EpochBasedRewardDistributor epochDistributor;
    MultiRewardsDistributor multiDistributor;

    address constant multiRewardsStaking = 0xc30911b52b5752447aB08615973e434c801CD652; // magicLP mim/usdc stip2
    address constant epochBasedStaking = 0x98164deD88e2a4862BdE8E7D4B831a6e3BE02D0A; // mim saving rate

    function setUp() public override {
        fork(ChainId.Arbitrum, 230248146);
        super.setUp();

        RewardDistributorsScript script = new RewardDistributorsScript();
        script.setTesting(true);

        (epochDistributor, multiDistributor) = script.deploy();
    }
}
