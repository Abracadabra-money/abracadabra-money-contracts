// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/RewardDistributors.s.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IEpochBasedStaking} from "interfaces/IEpochBasedStaking.sol";
import {IMultiRewardsStaking} from "interfaces/IMultiRewardsStaking.sol";

contract RewardDistributorsTest is BaseTest {
    using SafeTransferLib for address;

    event LogDistributed(address indexed staking, address indexed reward, uint256 amount);

    EpochBasedRewardDistributor epochDistributor;

    MultiRewardDistributor multiDistributor;

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

        vault = toolkit.getAddress("safe.ops");

        mim = toolkit.getAddress("mim");
        arb = toolkit.getAddress("arb");
        spell = toolkit.getAddress("spell");
        ospell = toolkit.getAddress("ospell");

        pushPrank(epochDistributor.owner());
        epochDistributor.setOperator(alice, true);
        epochDistributor.setVault(vault);
        popPrank();

        pushPrank(multiDistributor.owner());
        multiDistributor.setOperator(alice, true);
        multiDistributor.setVault(vault);
        popPrank();

        vm.label(multiRewardsStaking, "magicLP mim/usdc stip2");
        vm.label(epochBasedStaking, "mim saving rate");
    }

    function testNotAllowedOperator() public {
        vm.expectRevert(abi.encodeWithSignature("NotAllowedOperator()"));
        epochDistributor.distribute(epochBasedStaking);

        vm.expectRevert(abi.encodeWithSignature("NotAllowedOperator()"));
        multiDistributor.distribute(multiRewardsStaking);
    }

    function testDistributorWithoutConfiguration() public {
        pushPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("ErrNotReady()"));
        epochDistributor.distribute(epochBasedStaking);

        vm.expectRevert(abi.encodeWithSignature("ErrNotReady()"));
        multiDistributor.distribute(multiRewardsStaking);
        popPrank();
    }

    function testDistributeUnsupportedRewards() public {
        pushPrank(epochDistributor.owner());
        epochDistributor.setRewardDistribution(epochBasedStaking, toolkit.getAddress("usdt"), 1000e6);
        popPrank();

        pushPrank(multiDistributor.owner());
        multiDistributor.setRewardDistribution(multiRewardsStaking, toolkit.getAddress("usdt"), 1000e6);
        popPrank();

        pushPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("ErrNotReady()"));
        epochDistributor.distribute(epochBasedStaking);

        vm.expectRevert(abi.encodeWithSignature("ErrNotReady()"));
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
        deal(arb, vault, 1000 ether, true);

        pushPrank(epochDistributor.owner());
        epochDistributor.setRewardDistribution(epochBasedStaking, arb, 100 ether);
        popPrank();

        pushPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("TransferFromFailed()"));
        epochDistributor.distribute(epochBasedStaking);
        popPrank();
    }

    function testDistributeMultiNoAllowance() public {
        deal(arb, vault, 1000 ether, true);

        pushPrank(multiDistributor.owner());
        multiDistributor.setRewardDistribution(multiRewardsStaking, arb, 100 ether);
        popPrank();

        pushPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("TransferFromFailed()"));
        multiDistributor.distribute(multiRewardsStaking);
        popPrank();
    }

    function testEpochBasedDistribute() public {
        vm.warp(IEpochBasedStaking(epochBasedStaking).nextEpoch());

        deal(arb, vault, 1000 ether, true);
        deal(spell, vault, 10_000 ether, true);

        pushPrank(vault);
        arb.safeApprove(address(epochDistributor), 400 ether);
        spell.safeApprove(address(epochDistributor), 1000 ether);
        popPrank();

        pushPrank(epochDistributor.owner());
        epochDistributor.setRewardDistribution(epochBasedStaking, arb, 100 ether);
        popPrank();

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogDistributed(epochBasedStaking, arb, 100 ether);
        epochDistributor.distribute(epochBasedStaking);

        // not ready
        vm.expectRevert(abi.encodeWithSignature("ErrNotReady()"));
        epochDistributor.distribute(epochBasedStaking);

        vm.warp(IMultiRewardsStaking(epochBasedStaking).rewardData(arb).periodFinish);
        vm.expectEmit(true, true, true, true);
        emit LogDistributed(epochBasedStaking, arb, 100 ether);
        epochDistributor.distribute(epochBasedStaking);

        // not ready
        vm.expectRevert(abi.encodeWithSignature("ErrNotReady()"));
        epochDistributor.distribute(epochBasedStaking);

        // adding a new supported reward should make _not_ make it ready as everything needs to be
        pushPrank(epochDistributor.owner());
        epochDistributor.setRewardDistribution(epochBasedStaking, spell, 500 ether);
        popPrank();

        vm.expectEmit(true, true, true, true);
        emit LogDistributed(epochBasedStaking, spell, 500 ether);
        epochDistributor.distribute(epochBasedStaking);

        // not ready
        vm.expectRevert(abi.encodeWithSignature("ErrNotReady()"));
        epochDistributor.distribute(epochBasedStaking);

        vm.warp(IMultiRewardsStaking(epochBasedStaking).rewardData(spell).periodFinish);

        // should now distribute both spell and arb
        vm.expectEmit(true, true, true, true);
        emit LogDistributed(epochBasedStaking, arb, 100 ether);

        vm.expectEmit(true, true, true, true);
        emit LogDistributed(epochBasedStaking, spell, 500 ether);
        epochDistributor.distribute(epochBasedStaking);

        vm.expectRevert(abi.encodeWithSignature("ErrNotReady()"));
        epochDistributor.distribute(epochBasedStaking);

        popPrank();
    }

    function testMultiRewardsDistribute() public {
        deal(arb, vault, 1000 ether, true);
        deal(spell, vault, 10_000 ether, true);

        pushPrank(vault);
        arb.safeApprove(address(multiDistributor), 300 ether);
        spell.safeApprove(address(multiDistributor), 1000 ether);
        popPrank();

        pushPrank(multiDistributor.owner());
        multiDistributor.setRewardDistribution(multiRewardsStaking, arb, 100 ether);
        popPrank();

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogDistributed(multiRewardsStaking, arb, 100 ether);
        multiDistributor.distribute(multiRewardsStaking);

        // not ready
        vm.expectRevert(abi.encodeWithSignature("ErrNotReady()"));
        multiDistributor.distribute(multiRewardsStaking);

        vm.warp(IMultiRewardsStaking(multiRewardsStaking).rewardData(arb).periodFinish);
        vm.expectEmit(true, true, true, true);
        emit LogDistributed(multiRewardsStaking, arb, 100 ether);
        multiDistributor.distribute(multiRewardsStaking);

        // not ready
        vm.expectRevert(abi.encodeWithSignature("ErrNotReady()"));
        multiDistributor.distribute(multiRewardsStaking);

        // adding a new supported reward should make it ready
        pushPrank(multiDistributor.owner());
        multiDistributor.setRewardDistribution(multiRewardsStaking, spell, 500 ether);
        popPrank();

        vm.expectEmit(true, true, true, true);
        emit LogDistributed(multiRewardsStaking, spell, 500 ether);
        multiDistributor.distribute(multiRewardsStaking);

        // not ready
        vm.expectRevert(abi.encodeWithSignature("ErrNotReady()"));
        multiDistributor.distribute(multiRewardsStaking);

        vm.warp(IMultiRewardsStaking(multiRewardsStaking).rewardData(spell).periodFinish);

        // should now distribute both spell and arb
        vm.expectEmit(true, true, true, true);
        emit LogDistributed(multiRewardsStaking, arb, 100 ether);

        vm.expectEmit(true, true, true, true);
        emit LogDistributed(multiRewardsStaking, spell, 500 ether);
        multiDistributor.distribute(multiRewardsStaking);

        vm.expectRevert(abi.encodeWithSignature("ErrNotReady()"));
        multiDistributor.distribute(multiRewardsStaking);

        popPrank();
    }
}
