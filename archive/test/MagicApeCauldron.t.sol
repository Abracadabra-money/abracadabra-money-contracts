// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MagicApeCauldron.s.sol";
import "interfaces/IApeCoinStaking.sol";

contract MagicApeCauldronTest is BaseTest {
    ICauldronV4 cauldron;
    MagicApe magicApe;
    ProxyOracle oracle;
    ERC20 ape;
    IApeCoinStaking staking;

    address constant apeWhale = 0x91951FA186a77788197975ED58980221872a3352;
    uint256 apeBalance;

    function setUp() public override {
        fork(ChainId.Mainnet, 16581143);
        super.setUp();

        MagicApeCauldronScript script = new MagicApeCauldronScript();
        script.setTesting(true);
        (cauldron, magicApe, oracle) = script.deploy();

        ape = ERC20(toolkit.getAddress("mainnet.ape"));
        staking = IApeCoinStaking(toolkit.getAddress("mainnet.ape.staking"));
        apeBalance = ape.balanceOf(apeWhale);

        pushPrank(alice);
        ape.approve(address(magicApe), type(uint256).max);
        popPrank();

        pushPrank(bob);
        ape.approve(address(magicApe), type(uint256).max);
        popPrank();
    }

    function testOracle() public {
        assertEq(oracle.peekSpot(""), 162879798227112033);
    }

    function testMintBurn() public {
        _transferApe(alice, 1_000 ether);
        _transferApe(bob, 1_000 ether);

        pushPrank(alice);
        uint256 share = magicApe.deposit(1_000 ether, alice);
        assertEq(share, 1_000 ether);
        assertEq(magicApe.balanceOf(alice), 1_000 ether);
        popPrank();

        pushPrank(bob);
        share = magicApe.deposit(1_000 ether, bob);
        assertEq(share, 1_000 ether);
        assertEq(magicApe.balanceOf(bob), 1_000 ether);

        uint256 rewards = staking.pendingRewards(0, address(magicApe), 0);
        assertEq(rewards, 0);

        uint256 staked = staking.stakedTotal(address(magicApe));
        assertEq(staked, 2_000 ether);

        assertEq(magicApe.convertToAssets(1 ether), 1 ether);
        advanceTime(10 days);
        rewards = staking.pendingRewards(0, address(magicApe), 0);
        assertEq(rewards, 50346913151394102000);
        uint256 fees = (rewards * magicApe.feePercentBips()) / 10_000;
        // since totalAssets consider pending rewards, this shouldn't be valued at 1:1 anymore
        assertGt(magicApe.convertToAssets(1 ether), 1 ether);
        magicApe.harvest();

        // staking should now be 2000 + harvested rewards
        staked = staking.stakedTotal(address(magicApe));
        assertEq(staked, 2_000 ether + rewards - fees);
        popPrank();

        pushPrank(alice);
        magicApe.redeem(magicApe.balanceOf(alice), alice, alice);
        popPrank();

        pushPrank(bob);
        magicApe.redeem(magicApe.balanceOf(bob), bob, bob);
        popPrank();
    }

    function testMintingAndBurningWithFuzzing(
        uint256 amount1,
        uint256 amount2,
        uint256 rewards
    ) public {
        vm.assume(amount1 > 0);
        vm.assume(amount2 > 0);
        vm.assume(amount1 < apeBalance);
        vm.assume(amount2 < apeBalance);
        vm.assume(rewards < apeBalance);
        vm.assume(amount1 + amount2 + rewards < apeBalance);

        _transferApe(alice, amount1);
        _transferApe(bob, amount2);

        pushPrank(alice);
        uint256 share1 = magicApe.deposit(amount1, alice);
        popPrank();

        pushPrank(bob);
        uint256 share2 = magicApe.deposit(amount2, bob);
        popPrank();

        _transferApe(address(magicApe), rewards);
        magicApe.harvest();

        // edge case that shouldn't happen in a live situation, where there's not enough stake to cover
        // the redeem. that would happen if some user deposited less than 1e18, in which case it's not
        // staked in harvest()
        if (magicApe.convertToAssets(share1) <= staking.stakedTotal(address(this))) {
            pushPrank(alice);
            uint256 asset1 = magicApe.redeem(share1, alice, alice);
            assertGe(asset1, amount1);
            popPrank();
        }

        if (magicApe.convertToAssets(share2) <= staking.stakedTotal(address(this))) {
            pushPrank(bob);
            uint256 asset2 = magicApe.redeem(share2, bob, bob);
            assertGe(asset2, amount2);
            popPrank();
        }
    }

    function _transferApe(address to, uint256 amount) private {
        pushPrank(apeWhale);
        ape.transfer(to, amount);
        popPrank();
    }
}
