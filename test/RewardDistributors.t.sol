// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/RewardDistributors.s.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";

contract RewardDistributorsTest is BaseTest {
    EpochBasedRewardDistributor epochDistributor;
    MultiRewardsDistributor multiDistributor;

    address constant multiRewardsStaking = 0xc30911b52b5752447aB08615973e434c801CD652; // magicLP mim/usdc stip2
    address constant epochBasedStaking = 0x98164deD88e2a4862BdE8E7D4B831a6e3BE02D0A; // mim saving rate

    address vault;

    function setUp() public override {
        fork(ChainId.Arbitrum, 230248146);
        super.setUp();

        RewardDistributorsScript script = new RewardDistributorsScript();
        script.setTesting(true);

        (epochDistributor, multiDistributor) = script.deploy();

        pushPrank(Owned(epochBasedStaking).owner());
        OperatableV2(epochBasedStaking).setOperator(address(epochDistributor), true);
        popPrank();

        pushPrank(Owned(multiRewardsStaking).owner());
        OperatableV2(multiRewardsStaking).setOperator(address(multiDistributor), true);
        popPrank();

        vault = makeAddr("safe.rewards");

        pushPrank(epochDistributor.owner());
        epochDistributor.setOperator(alice, true);
        epochDistributor.setVault(vault);
        popPrank();

        pushPrank(multiDistributor.owner());
        multiDistributor.setOperator(alice, true);
        multiDistributor.setVault(vault);
        popPrank();
    }

    function testNotAllowedOperator() public {
        vm.expectRevert(abi.encodeWithSignature("NotAllowedOperator()"));
        epochDistributor.distribute(epochBasedStaking);

        vm.expectRevert(abi.encodeWithSignature("NotAllowedOperator()"));
        multiDistributor.distribute(multiRewardsStaking);
    }

    function testDistributorWithoutConfiguration() public {
        pushPrank(alice);
        epochDistributor.distribute(epochBasedStaking);
        multiDistributor.distribute(multiRewardsStaking);
        popPrank();
    }

    function testDistributeUnsupportedRewards() public {
        pushPrank(epochDistributor.owner());
        epochDistributor.setOperator(alice, true);
        epochDistributor.setVault(vault);
        popPrank();

        pushPrank(multiDistributor.owner());
        multiDistributor.setOperator(alice, true);
        multiDistributor.setVault(vault);
        popPrank();

        pushPrank(alice);
        epochDistributor.distribute(epochBasedStaking);
        multiDistributor.distribute(multiRewardsStaking);
        popPrank();
    }

    function testDistributeMissingRewardsOnVault() public {
        pushPrank(alice);
        epochDistributor.distribute(epochBasedStaking);
        multiDistributor.distribute(multiRewardsStaking);
        popPrank();
    }

    function _setupRewards() internal {}
}
