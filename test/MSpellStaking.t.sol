// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MSpellStaking.s.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IRewardHandler} from "/staking/MSpellStaking.sol";
import "forge-std/console2.sol";

contract RewardHandler is IRewardHandler {
    using SafeTransferLib for address;

    function handle(address _token, address _user, uint256 _amount) external payable {
        if(msg.value == 0) {
            revert("RewardHandler: invalid msg.value");
        }
        _token.safeTransfer(_user, _amount - 1 ether);
    }
}

contract MSpellStakingTest is BaseTest {
    using SafeTransferLib for address;

    MSpellStaking staking;
    address mim;
    address spell;

    function setUp() public override {
        fork(ChainId.Mainnet, 20215675);
        super.setUp();

        MSpellStakingScript script = new MSpellStakingScript();
        script.setTesting(true);
        mim = toolkit.getAddress(block.chainid, "mim");
        spell = toolkit.getAddress(block.chainid, "spell");

        (staking) = script.deploy();
    }

    function testRewardHandler() public {
        deal(spell, alice, 10_000 ether);

        pushPrank(alice);
        spell.safeApprove(address(staking), 10_000 ether);
        staking.deposit(10_000 ether);

        _distributeRewards(100 ether);

        uint before = mim.balanceOf(alice);
        staking.deposit(0);
        assertEq(mim.balanceOf(alice), before + 100 ether);
        before = mim.balanceOf(alice);
        staking.deposit(0);
        assertEq(mim.balanceOf(alice), before);

        pushPrank(staking.owner());
        staking.setRewardHandler(address(new RewardHandler()));
        popPrank();

        _distributeRewards(100 ether);
        before = mim.balanceOf(alice);
        staking.deposit{value: 1 ether}(0);
        assertEq(mim.balanceOf(alice), before + 99 ether);

        advanceTime(2 days);
        staking.withdraw{value: 1 ether}(0);
        popPrank();
    }

    function _distributeRewards(uint amount) internal {
        deal(mim, address(staking), amount, true);
        staking.updateReward();
    }
}
