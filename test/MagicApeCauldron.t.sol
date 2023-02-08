// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MagicApeCauldron.s.sol";
import "interfaces/IApeCoinStaking.sol";

contract MyTest is BaseTest {
    ICauldronV4 cauldron;
    MagicApe magicApe;
    ProxyOracle oracle;
    ERC20 ape;
    IApeCoinStaking staking;

    function setUp() public override {
        forkMainnet(16581143);
        super.setUp();

        MagicApeCauldronScript script = new MagicApeCauldronScript();
        script.setTesting(true);
        (cauldron, magicApe, oracle) = script.run();

        ape = ERC20(constants.getAddress("mainnet.ape"));
        staking = IApeCoinStaking(constants.getAddress("mainnet.ape.staking"));
    }

    function testOracle() public {
        assertEq(oracle.peekSpot(""), 162879798227112033);
    }

    function testMintBurn() public {
        _transferApe(alice, 1_000 ether);
        _transferApe(bob, 1_000 ether);

        pushPrank(alice);
        ape.approve(address(magicApe), type(uint256).max);
        uint256 share = magicApe.deposit(1_000 ether, alice);
        assertEq(share, 1_000 ether);
        assertEq(magicApe.balanceOf(alice), 1_000 ether);
        popPrank();

        pushPrank(bob);
        ape.approve(address(magicApe), type(uint256).max);
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
        uint fees = (rewards * magicApe.feePercentBips()) / 10_000;
        // since totalAssets consider pending rewards, this shouldn't be valued at 1:1 anymore
        assertGt(magicApe.convertToAssets(1 ether), 1 ether);
        magicApe.harvest();

        // staking should now be 2000 + harvested rewards
        staked = staking.stakedTotal(address(magicApe));
        assertEq(staked, 2_000 ether + rewards - fees);
        popPrank();
    }

    function _transferApe(address to, uint256 amount) private {
        address apeWhale = 0x91951FA186a77788197975ED58980221872a3352;
        pushPrank(apeWhale);
        ape.transfer(to, amount);
        popPrank();
    }
}
