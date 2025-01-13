// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/SpellPowerBoundSpellDistributor.s.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SpellPowerBoundSpellDistributor} from "/staking/distributors/SpellPowerBoundSpellDistributor.sol";
import {SpellPowerStaking} from "/staking/SpellPowerStaking.sol";
import {TokenLocker} from "/periphery/TokenLocker.sol";

contract SpellPowerBoundSpellDistributorTest is BaseTest {
    using SafeTransferLib for address;

    event LogRewardAdded(uint256 reward);

    SpellPowerBoundSpellDistributor distributor;
    SpellPowerStaking staking;
    TokenLocker locker;
    address spell;
    address bSpell;

    function setUp() public override {
        fork(ChainId.Arbitrum, 293448643);
        super.setUp();

        SpellPowerBoundSpellDistributorScript script = new SpellPowerBoundSpellDistributorScript();
        script.setTesting(true);
        (distributor) = script.deploy();

        locker = TokenLocker(toolkit.getAddress("bSpell.locker"));
        pushPrank(locker.owner());
        locker.updateInstantRedeemParams(
            TokenLocker.InstantRedeemParams({
                feeCollector: address(distributor),
                immediateBips: 5000, // 50%
                burnBips: 3000 // 30%
            })
        );
        popPrank();

        spell = toolkit.getAddress("spellV2");
        bSpell = distributor.bSpell();

        staking = SpellPowerStaking(address(distributor.staking()));

        pushPrank(staking.owner());
        staking.grantRoles(address(distributor), staking.ROLE_REWARD_DISTRIBUTOR());
        popPrank();
    }

    function testDistribute() public {
        assertEq(bSpell.balanceOf(address(distributor)), 0, "bSpell balance should be 0");

        uint256 amount = 1000 ether;
        _mintbSpell(amount, alice);

        pushPrank(alice);
        locker.instantRedeem(amount, alice);
        popPrank();

        uint256 rewards = (amount * 20) / 100;
        assertEq(bSpell.balanceOf(address(distributor)), rewards, "bSpell balance should be equal to amount minted");

        address gelato = toolkit.getAddress("safe.devOps.gelatoProxy");
        pushPrank(gelato);
        vm.expectEmit(true, true, true, true);
        emit LogRewardAdded(rewards / 2);
        distributor.distribute(rewards / 2);
        assertEq(bSpell.balanceOf(address(distributor)), rewards / 2, "bSpell balance should be equal to rewards");
        popPrank();
    }

    function _mintbSpell(uint256 amount, address to) internal {
        address owner = locker.owner();
        uint256 balance = spell.balanceOf(owner);
        deal(spell, owner, amount, true);
        assertGe(spell.balanceOf(address(owner)), balance + amount);

        pushPrank(owner);
        spell.safeApprove(address(locker), amount);

        uint supplyBefore = IERC20Metadata(bSpell).totalSupply();
        locker.mint(amount, to);
        assertEq(IERC20Metadata(bSpell).totalSupply(), supplyBefore + amount, "supply didn't change?");
        assertEq(bSpell.balanceOf(to), amount, "bSpell balance should be equal to amount minted");
        popPrank();
    }

    function testRescue() public {
        uint256 amount = 1000 ether;
        _mintbSpell(amount, address(distributor));

        pushPrank(distributor.owner());
        distributor.rescue(address(bSpell), amount);
        popPrank();

        assertEq(bSpell.balanceOf(address(distributor)), 0, "bSpell balance should be 0");
        assertEq(bSpell.balanceOf(distributor.owner()), amount, "bSpell balance should be equal to amount rescued");
    }
}
