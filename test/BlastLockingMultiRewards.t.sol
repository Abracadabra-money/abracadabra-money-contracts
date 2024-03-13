// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import {BlastLockingMultiRewards} from "/blast/BlastLockingMultiRewards.sol";
import {BlastTokenRegistry} from "/blast/BlastTokenRegistry.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {BlastToken} from "utils/mocks/BlastMock.sol";

contract BlastLockingMultiRewardsTest is BaseTest {
    BlastLockingMultiRewards staking;
    address usdb;
    address weth;
    address mim;
    address owner;
    address feeTo;
    BlastTokenRegistry registry;

    function setUp() public override {
        fork(ChainId.Blast, 701141);
        super.setUp();

        registry = BlastTokenRegistry(toolkit.getAddress(ChainId.Blast, "blastTokenRegistry"));
        mim = toolkit.getAddress(ChainId.Blast, "mim");
        usdb = toolkit.getAddress(ChainId.Blast, "usdb");
        weth = toolkit.getAddress(ChainId.Blast, "weth");

        owner = alice;
        feeTo = bob;

        staking = new BlastLockingMultiRewards(registry, feeTo, usdb, 30000, 7 days, 13 weeks, owner);

        pushPrank(owner);
        staking.addReward(weth);
        popPrank();
    }

    function testAddRewardsAndClaimYields() public {
        pushPrank(owner);
        vm.expectRevert(abi.encodeWithSignature("ErrRewardAlreadyExists()"));
        staking.addReward(weth);

        // Token not registered as native yields
        address mockToken1 = address(new BlastToken(18));
        vm.expectRevert(abi.encodeWithSignature("ErrInvalidTokenAddress()"));
        staking.claimTokenYields(mockToken1);

        staking.addReward(mockToken1);
        vm.expectRevert(abi.encodeWithSignature("ErrNotNativeYieldToken()"));
        staking.claimTokenYields(mockToken1);

        pushPrank(registry.owner());
        registry.setNativeYieldTokenEnabled(mockToken1, true);
        popPrank();

        vm.expectRevert(abi.encodeWithSignature("NotClaimableAccount()"));
        staking.claimTokenYields(mockToken1);

        staking.updateTokenClaimables(mockToken1);
        staking.claimTokenYields(mockToken1);

        // Token already registered as native yields
        address mockToken2 = address(new BlastToken(18));
        pushPrank(registry.owner());
        registry.setNativeYieldTokenEnabled(mockToken2, true);
        popPrank();
        staking.addReward(mockToken2);
        staking.claimTokenYields(mockToken2);

        popPrank();
    }

    function testGasClaim() public {
        pushPrank(owner);
        staking.claimGasYields();
        popPrank();
    }
}
