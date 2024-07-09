// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/RewardDistributors.s.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";

contract RewardDistributorsTest is BaseTest {
    event LogDistributed(address indexed staking, address indexed reward, uint256 amount);

    EpochBasedRewardDistributor epochDistributor;

    MultiRewardsDistributor multiDistributor;

    address constant multiRewardsStaking = 0xc30911b52b5752447aB08615973e434c801CD652; // magicLP mim/usdc stip2
    address constant epochBasedStaking = 0x98164deD88e2a4862BdE8E7D4B831a6e3BE02D0A; // mim saving rate

    address vault;
    address mim;
    address arb;
    address spell;
    address ospell;

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

        vault = toolkit.getAddress(block.chainid, "safe.rewards");

        mim = toolkit.getAddress(block.chainid, "mim");
        arb = toolkit.getAddress(block.chainid, "arb");
        spell = toolkit.getAddress(block.chainid, "spell");
        ospell = toolkit.getAddress(block.chainid, "ospell");

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
        epochDistributor.setRewardDistribution(epochBasedStaking, toolkit.getAddress(block.chainid, "usdt"), 1000e6);
        popPrank();

        pushPrank(multiDistributor.owner());
        multiDistributor.setRewardDistribution(multiRewardsStaking, toolkit.getAddress(block.chainid, "usdt"), 1000e6);
        popPrank();

        pushPrank(alice);
        epochDistributor.distribute(epochBasedStaking);
        multiDistributor.distribute(multiRewardsStaking);
        popPrank();
    }

    function testDistributeEpochBasedMissingRewards() public {
        pushPrank(epochDistributor.owner());
        epochDistributor.setRewardDistribution(epochBasedStaking, arb, 100 ether);
        popPrank();

        pushPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("TransferFromFailed()"));
        epochDistributor.distribute(epochBasedStaking);
        popPrank();
    }

    function testDistributeMultiMissingRewards() public {
        pushPrank(multiDistributor.owner());
        multiDistributor.setRewardDistribution(multiRewardsStaking, arb, 100 ether);
        popPrank();

        pushPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("TransferFromFailed()"));
        multiDistributor.distribute(multiRewardsStaking);
        popPrank();
    }

    function testDistributeEpochBasedNoAllowance() public {
        deal(vault, arb, 1000 ether, true);

        pushPrank(epochDistributor.owner());
        epochDistributor.setRewardDistribution(epochBasedStaking, arb, 100 ether);
        popPrank();

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogDistributed(epochBasedStaking, arb, 100 ether);
        epochDistributor.distribute(epochBasedStaking);
        popPrank();
    }

    function testDistributeMultiNoAllowance() public {
        deal(vault, arb, 1000 ether, true);

        pushPrank(multiDistributor.owner());
        multiDistributor.setRewardDistribution(multiRewardsStaking, arb, 100 ether);
        popPrank();

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogDistributed(epochBasedStaking, arb, 100 ether);
        multiDistributor.distribute(multiRewardsStaking);
        popPrank();
    }

    function xtestDistributeEpochBased() public {
        deal(vault, arb, 1000 ether, true);

        pushPrank(epochDistributor.owner());
        epochDistributor.setRewardDistribution(epochBasedStaking, arb, 100 ether);
        popPrank();

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogDistributed(epochBasedStaking, arb, 100 ether);
        epochDistributor.distribute(epochBasedStaking);
        popPrank();
    }

    function xtestDistributeMulti() public {
        deal(vault, arb, 1000 ether, true);

        pushPrank(multiDistributor.owner());
        multiDistributor.setRewardDistribution(multiRewardsStaking, arb, 100 ether);
        popPrank();

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogDistributed(epochBasedStaking, arb, 100 ether);
        multiDistributor.distribute(multiRewardsStaking);
        popPrank();
    }
}
