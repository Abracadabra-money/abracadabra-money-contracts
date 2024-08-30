// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/Governance.s.sol";
import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {MSpellStakingHub} from "/governance/MSpellStakingWithVoting.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {Ownable} from "@solady/auth/Ownable.sol";
import {UUPSUpgradeable} from "@solady/utils/UUPSUpgradeable.sol";

contract SpellTimelockV2 is TimelockControllerUpgradeable, Ownable, UUPSUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin) external reinitializer(2) {
        __TimelockController_init(minDelay, proposers, executors, admin);
        _initializeOwner(admin);
    }

    function _authorizeUpgrade(address) internal virtual override {
        _checkOwner();
    }
}

contract GovernanceTest is BaseTest {
    using SafeTransferLib for address;

    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    SpellTimelock timelock;
    address timelockAdmin;
    MSpellStakingHub staking;
    address mim;
    address spell;

    function setUp() public override {
        fork(ChainId.Arbitrum, 225241370);
        super.setUp();

        mim = toolkit.getAddress(block.chainid, "mim");
        spell = toolkit.getAddress(block.chainid, "spell");

        GovernanceScript script = new GovernanceScript();
        script.setTesting(true);

        (timelock, timelockAdmin, staking) = script.deploy();

        pushPrank(timelockAdmin);
        timelock.grantRole(EXECUTOR_ROLE, alice);
        timelock.grantRole(PROPOSER_ROLE, alice);
        popPrank();

        pushPrank(tx.origin);
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), tx.origin);
        popPrank();
    }

    function testUpdateTimelockSettings() public {
        pushPrank(alice);
        assertEq(timelock.getMinDelay(), 2 days);

        timelock.schedule(
            address(timelock),
            0,
            abi.encodeCall(TimelockControllerUpgradeable.updateDelay, 1 days),
            bytes32(0),
            bytes32(0),
            timelock.getMinDelay()
        );
        advanceTime(2 days);
        timelock.execute(address(timelock), 0, abi.encodeCall(TimelockControllerUpgradeable.updateDelay, 1 days), bytes32(0), bytes32(0));
        assertEq(timelock.getMinDelay(), 1 days);
        popPrank();
    }

    function testUpdateTimelockUpgrade() public {
        pushPrank(alice);
        SpellTimelockV2 newTimelock = new SpellTimelockV2();

        assertEq(timelock.getMinDelay(), 2 days);
        timelock.schedule(
            address(timelock),
            0,
            abi.encodeCall(TimelockControllerUpgradeable.updateDelay, 1 days),
            bytes32(0),
            bytes32(0),
            timelock.getMinDelay()
        );
        advanceTime(2 days);
        timelock.execute(address(timelock), 0, abi.encodeCall(TimelockControllerUpgradeable.updateDelay, 1 days), bytes32(0), bytes32(0));
        assertEq(timelock.getMinDelay(), 1 days);
        popPrank();

        pushPrank(timelock.owner());
        timelock.upgradeToAndCall(
            address(newTimelock),
            abi.encodeWithSelector(SpellTimelock.initialize.selector, 2 days, new address[](0), new address[](0), tx.origin)
        );
        popPrank();
        assertEq(timelock.getMinDelay(), 2 days);
    }

    function testVotingStaking() public {
        uint mSpellBalance = staking.balanceOf(alice);
        assertEq(mSpellBalance, 0);

        deal(spell, alice, 10_000 ether);

        pushPrank(alice);
        spell.safeApprove(address(staking), 10_000 ether);
        staking.deposit(10_000 ether);

        assertEq(staking.balanceOf(alice), 10_000 ether);

        vm.expectRevert(abi.encodeWithSignature("ErrLockedUp()"));
        staking.withdraw(1000 ether);

        pushPrank(staking.owner());
        staking.setToggleLockUp(false);
        popPrank();

        staking.withdraw(1000 ether);

        assertEq(staking.balanceOf(alice), 9000 ether);
        popPrank();
    }

    function testCannotTransferMSpell() public {
        deal(spell, alice, 10_000 ether);

        pushPrank(alice);
        spell.safeApprove(address(staking), 10_000 ether);
        staking.deposit(10_000 ether);

        vm.expectRevert(abi.encodeWithSignature("ErrUnsupportedOperation()"));
        staking.transfer(bob, 1000 ether);

        popPrank();
    }

    function testCannotApproveMSpell() public {
        deal(spell, alice, 10_000 ether);

        pushPrank(alice);
        spell.safeApprove(address(staking), 10_000 ether);
        staking.deposit(10_000 ether);

        vm.expectRevert(abi.encodeWithSignature("ErrUnsupportedOperation()"));
        staking.approve(bob, 1000 ether);

        popPrank();
    }

    function testCannotTransferFromMSpell() public {
        deal(spell, alice, 10_000 ether);

        pushPrank(alice);
        spell.safeApprove(address(staking), 10_000 ether);
        staking.deposit(10_000 ether);

        vm.expectRevert(abi.encodeWithSignature("ErrUnsupportedOperation()"));
        staking.transferFrom(alice, bob, 1000 ether);

        popPrank();
    }

    function testCannotPermitMSpell() public {
        deal(spell, alice, 10_000 ether);

        pushPrank(alice);
        spell.safeApprove(address(staking), 10_000 ether);
        staking.deposit(10_000 ether);

        vm.expectRevert(abi.encodeWithSignature("ErrUnsupportedOperation()"));
        staking.permit(alice, bob, 1000 ether, 0, 0, 0, 0);

        popPrank();
    }
}
