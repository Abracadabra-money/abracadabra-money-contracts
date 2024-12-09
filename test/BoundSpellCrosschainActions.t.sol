// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/BoundSpellCrosschainActions.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILzOFTV2} from "@abracadabra-oftv2/interfaces/ILayerZero.sol";
import {BoundSpellActionSender, BoundSpellActionReceiver, CrosschainActions, MintBoundSpellAndStakeParams, StakeBoundSpellParams, Payload} from "src/periphery/BoundSpellCrosschainActions.sol";
import {SpellPowerStaking} from "src/staking/SpellPowerStaking.sol";
import {TokenLocker} from "src/periphery/TokenLocker.sol";
import {RewardHandlerParams} from "src/staking/MultiRewards.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

interface ILzBaseOFTV2 is ILzOFTV2 {
    function innerToken() external view returns (address);
}

contract BoundSpellCrosschainActionsTest is BaseTest {
    BoundSpellActionSender sender;
    BoundSpellActionReceiver receiver;
    SpellPowerStaking spellPowerStaking;
    TokenLocker boundSpellLocker;
    BoundSpellCrosschainActionsScript script;

    struct ChainTokens {
        address spell;
        address bSpell;
        ILzOFTV2 spellOft;
        ILzOFTV2 bSpellOft;
    }

    mapping(uint16 => ChainTokens) public chainTokens;

    uint256 constant ARBITRUM_BLOCK = 262044597;
    uint256 constant MAINNET_BLOCK = 20928862;

    uint16 constant ARBITRUM_CHAIN_ID = 110;
    uint16 constant MAINNET_CHAIN_ID = 101;

    uint256 mainnetFork;
    uint256 arbitrumFork;

    function setUp() public override {
        // Create forks
        mainnetFork = fork(ChainId.Mainnet, MAINNET_BLOCK);
        arbitrumFork = fork(ChainId.Arbitrum, ARBITRUM_BLOCK);

        // Start with Mainnet fork for sender setup
        vm.selectFork(mainnetFork);
        super.setUp();
        script = new BoundSpellCrosschainActionsScript();

        script.setTesting(true);

        // Deploy sender on Mainnet
        address deployedContract = script.deploy();
        sender = BoundSpellActionSender(deployedContract);

        assertNotEq(address(sender), address(0), "sender is not deployed");

        // Setup Mainnet-specific contracts
        chainTokens[MAINNET_CHAIN_ID] = ChainTokens({
            spell: ILzBaseOFTV2(toolkit.getAddress("spell.oftv2")).innerToken(),
            bSpell: ILzBaseOFTV2(toolkit.getAddress("bspell.oftv2")).innerToken(),
            spellOft: ILzOFTV2(toolkit.getAddress("spell.oftv2")),
            bSpellOft: ILzOFTV2(toolkit.getAddress("bspell.oftv2"))
        });

        // Switch to Arbitrum fork for receiver setup
        vm.selectFork(arbitrumFork);
        script = new BoundSpellCrosschainActionsScript();

        // Deploy receiver on Arbitrum
        deployedContract = script.deploy();
        receiver = BoundSpellActionReceiver(deployedContract);

        assertNotEq(address(receiver), address(0), "receiver is not deployed");
        assertEq(receiver.remoteSender(), bytes32(uint256(uint160(address(sender)))), "remoteSender is not correct on Arbitrum");

        // Setup Arbitrum-specific contracts
        chainTokens[ARBITRUM_CHAIN_ID] = ChainTokens({
            spell: ILzBaseOFTV2(toolkit.getAddress("spell.oftv2")).innerToken(),
            bSpell: ILzBaseOFTV2(toolkit.getAddress("bspell.oftv2")).innerToken(),
            spellOft: ILzOFTV2(toolkit.getAddress("spell.oftv2")),
            bSpellOft: ILzOFTV2(toolkit.getAddress("bspell.oftv2"))
        });

        spellPowerStaking = SpellPowerStaking(toolkit.getAddress("bSpell.staking"));
        boundSpellLocker = TokenLocker(toolkit.getAddress("bSpell.locker"));

        // set the receiver contract as an operator for spellPowerStaking and boundSpellLocker
        pushPrank(spellPowerStaking.owner());
        OwnableRoles(address(spellPowerStaking)).grantRoles(address(receiver), spellPowerStaking.ROLE_OPERATOR());
        popPrank();

        pushPrank(boundSpellLocker.owner());
        OwnableOperators(address(boundSpellLocker)).setOperator(address(receiver), true);
        popPrank();

        SpellPowerStaking stakingImpl = new SpellPowerStaking(address(chainTokens[ARBITRUM_CHAIN_ID].bSpell), address(0));
        pushPrank(spellPowerStaking.owner());
        spellPowerStaking.upgradeToAndCall(address(stakingImpl), "");
        popPrank();
    }

    function testDeployment() public {
        // Test sender deployment on Mainnet
        vm.selectFork(mainnetFork);
        assertEq(address(sender.spellOft()), address(chainTokens[MAINNET_CHAIN_ID].spellOft), "spellOft is not correct on Mainnet");
        assertEq(address(sender.bSpellOft()), address(chainTokens[MAINNET_CHAIN_ID].bSpellOft), "bSpellOft is not correct on Mainnet");
        assertEq(sender.spell(), address(chainTokens[MAINNET_CHAIN_ID].spell), "spell is not correct on Mainnet");
        assertEq(sender.bSpell(), address(chainTokens[MAINNET_CHAIN_ID].bSpell), "bSpellV2 is not correct on Mainnet");

        // Test receiver deployment on Arbitrum
        vm.selectFork(arbitrumFork);
        assertEq(address(receiver.spellOft()), address(chainTokens[ARBITRUM_CHAIN_ID].spellOft), "spellOft is not correct on Arbitrum");
        assertEq(address(receiver.bSpellOft()), address(chainTokens[ARBITRUM_CHAIN_ID].bSpellOft), "bSpellOft is not correct on Arbitrum");
        assertEq(receiver.spell(), address(chainTokens[ARBITRUM_CHAIN_ID].spell), "spell is not correct on Arbitrum");
        assertEq(receiver.bSpell(), address(chainTokens[ARBITRUM_CHAIN_ID].bSpell), "bSpellV2 is not correct on Arbitrum");
        assertEq(address(receiver.spellPowerStaking()), address(spellPowerStaking), "spellPowerStaking is not correct on Arbitrum");
        assertEq(address(receiver.boundSpellLocker()), address(boundSpellLocker), "boundSpellLocker is not correct on Arbitrum");
    }

    function testSendMintAndStakeBoundSpell() public {
        // Test sender on Mainnet
        vm.selectFork(mainnetFork);
        uint256 amount = 1000e18;
        deal(address(chainTokens[MAINNET_CHAIN_ID].spell), alice, amount);

        pushPrank(alice);
        IERC20 spellToken = IERC20(address(chainTokens[MAINNET_CHAIN_ID].spell));
        uint256 aliceBalanceBefore = spellToken.balanceOf(alice);
        spellToken.approve(address(sender), amount);

        (uint256 fee, ) = sender.estimate(CrosschainActions.MINT_AND_STAKE_BOUNDSPELL);
        sender.send{value: fee}(CrosschainActions.MINT_AND_STAKE_BOUNDSPELL, amount);
        popPrank();

        uint256 aliceBalanceAfter = spellToken.balanceOf(alice);
        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount, "SPELL balance should decrease by the sent amount");

        // Test receiver on Arbitrum
        vm.selectFork(arbitrumFork);
        bytes memory params = abi.encode(MintBoundSpellAndStakeParams(alice));
        bytes memory payload = abi.encode(Payload(CrosschainActions.MINT_AND_STAKE_BOUNDSPELL, params));

        pushPrank(address(chainTokens[MAINNET_CHAIN_ID].spellOft));

        // simulate receiving spell on Arbitrum
        deal(address(chainTokens[ARBITRUM_CHAIN_ID].spell), address(receiver), amount);
        
        uint256 stakingBalanceBefore = spellPowerStaking.balanceOf(alice);

        receiver.onOFTReceived(MAINNET_CHAIN_ID, "", 0, bytes32(uint256(uint160(address(sender)))), amount, payload);

        uint256 stakingBalanceAfter = spellPowerStaking.balanceOf(alice);
        assertEq(stakingBalanceAfter - stakingBalanceBefore, amount, "Staking balance should increase by the sent amount");

        assertEq(
            IERC20(address(chainTokens[ARBITRUM_CHAIN_ID].bSpell)).balanceOf(address(spellPowerStaking)),
            amount
        );
    }

    function testSendStakeBoundSpell() public {
        vm.selectFork(mainnetFork);
        uint256 amount = 1000e18;

        deal(address(chainTokens[MAINNET_CHAIN_ID].bSpell), alice, amount);

        pushPrank(alice);
        IERC20 bSpellToken = IERC20(address(chainTokens[MAINNET_CHAIN_ID].bSpell));
        uint256 aliceBalanceBefore = bSpellToken.balanceOf(alice);
        bSpellToken.approve(address(sender), amount);

        (uint256 fee, ) = sender.estimate(CrosschainActions.STAKE_BOUNDSPELL);
        sender.send{value: fee}(CrosschainActions.STAKE_BOUNDSPELL, amount);
        popPrank();

        uint256 aliceBalanceAfter = bSpellToken.balanceOf(alice);
        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount, "bSpell balance should decrease by the sent amount");

        // Simulate LzReceive on Arbitrum (instead of Mainnet)
        vm.selectFork(arbitrumFork);

        bytes memory params = abi.encode(StakeBoundSpellParams(alice));
        bytes memory payload = abi.encode(Payload(CrosschainActions.STAKE_BOUNDSPELL, params));

        // Simulate receiving bSpell on the receiver, not the oft, the inner token
        deal(address(chainTokens[ARBITRUM_CHAIN_ID].bSpell), address(receiver), amount);

        uint256 stakingBalanceBefore = spellPowerStaking.balanceOf(alice);

        pushPrank(address(chainTokens[MAINNET_CHAIN_ID].bSpellOft));
        receiver.onOFTReceived(MAINNET_CHAIN_ID, "", 0, bytes32(uint256(uint160(address(sender)))), amount, payload);

        uint256 stakingBalanceAfter = spellPowerStaking.balanceOf(alice);
        assertEq(stakingBalanceAfter - stakingBalanceBefore, amount, "Staking balance should increase by the sent amount");
    }

    function testPauseUnpause() public {
        vm.selectFork(mainnetFork);
        pushPrank(sender.owner());
        sender.pause();
        assertTrue(sender.paused());

        vm.expectRevert(Pausable.EnforcedPause.selector);
        sender.send(CrosschainActions.MINT_AND_STAKE_BOUNDSPELL, 1000e18);

        pushPrank(sender.owner());
        sender.unpause();
        assertFalse(sender.paused());

        vm.selectFork(arbitrumFork);
        pushPrank(receiver.owner());
        receiver.pause();
        assertTrue(receiver.paused());

        vm.expectRevert(Pausable.EnforcedPause.selector);
        receiver.onOFTReceived(ARBITRUM_CHAIN_ID, "", 0, bytes32(uint256(uint160(address(sender)))), 1000e18, "");
    }

    function testRescueSender() public {
        vm.selectFork(mainnetFork);
        uint256 amount = 1000e18;
        deal(chainTokens[MAINNET_CHAIN_ID].spell, address(sender), amount);

        pushPrank(sender.owner());
        sender.rescue(chainTokens[MAINNET_CHAIN_ID].spell, amount, sender.owner());

        assertEq(IERC20(chainTokens[MAINNET_CHAIN_ID].spell).balanceOf(sender.owner()), amount);
    }

    function testRescueReceiver() public {
        uint256 amount = 1000e18;
        deal(chainTokens[ARBITRUM_CHAIN_ID].bSpell, address(receiver), amount);

        pushPrank(receiver.owner());
        receiver.rescue(chainTokens[ARBITRUM_CHAIN_ID].bSpell, amount, receiver.owner());

        assertEq(IERC20(chainTokens[ARBITRUM_CHAIN_ID].bSpell).balanceOf(receiver.owner()), amount);
    }

    function testInvalidSender() public {
        // Remove fork call and adjust assertions as needed
        bytes memory payload = abi.encode(
            CrosschainActions.MINT_AND_STAKE_BOUNDSPELL,
            abi.encode(MintBoundSpellAndStakeParams(alice))
        );

        vm.expectRevert(BoundSpellActionReceiver.ErrInvalidSender.selector);
        receiver.onOFTReceived(ARBITRUM_CHAIN_ID, "", 0, bytes32(uint256(uint160(address(sender)))), 1000e18, payload);
    }

    function testInvalidSourceChainId() public {
        // Remove fork call and adjust assertions as needed
        bytes memory payload = abi.encode(
            CrosschainActions.MINT_AND_STAKE_BOUNDSPELL,
            abi.encode(MintBoundSpellAndStakeParams(alice))
        );

        pushPrank(address(chainTokens[ARBITRUM_CHAIN_ID].spellOft));
        vm.expectRevert(BoundSpellActionReceiver.ErrInvalidSourceChainId.selector);
        receiver.onOFTReceived(ARBITRUM_CHAIN_ID, "", 0, bytes32(uint256(uint160(address(sender)))), 1000e18, payload);
    }

    function testInvalidAction() public {
        vm.selectFork(arbitrumFork);

        // Create an invalid action (using an out-of-range value for CrosschainActions)
        bytes memory params = abi.encode(StakeBoundSpellParams(alice));
        bytes memory payload = abi.encode(999, params);

        pushPrank(address(chainTokens[ARBITRUM_CHAIN_ID].bSpellOft));
        vm.expectRevert();
        receiver.onOFTReceived(ARBITRUM_CHAIN_ID, "", 0, bytes32(uint256(uint160(address(sender)))), 1000e18, payload);
    }
}
