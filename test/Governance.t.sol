// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/Governance.s.sol";
import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {MSpellStakingHub, MessageType} from "/governance/MSpellStakingWithVoting.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {Ownable} from "@solady/auth/Ownable.sol";
import {UUPSUpgradeable} from "@solady/utils/UUPSUpgradeable.sol";
import {LayerZeroTestLib} from "./utils/LayerZeroTestLib.sol";

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

    function initializedVersion() public view returns (uint64) {
        return _getInitializedVersion();
    }

    function foo() external pure returns (uint256) {
        return 123;
    }
}

contract GovernanceTest is BaseTest {
    using SafeTransferLib for address;

    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    SpellTimelock timelock;
    address timelockAdmin;
    MSpellStakingHub stakingHub;
    MSpellStakingSpoke stakingSpoke;
    address mim;
    address spell;

    function setUp() public override {
        fork(ChainId.Arbitrum, 225241370);
        super.setUp();

        mim = toolkit.getAddress(block.chainid, "mim");
        spell = toolkit.getAddress(block.chainid, "spell");

        GovernanceScript script = new GovernanceScript();
        script.setTesting(true);

        (timelock, timelockAdmin, stakingHub, ) = script.deploy();

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

        assertEq(timelock.initializedVersion(), 2);

        assertEq(SpellTimelockV2(payable(address(timelock))).foo(), 123);
        popPrank();
        assertEq(timelock.getMinDelay(), 2 days);
    }

    function testVotingStaking() public {
        uint mSpellBalance = stakingHub.balanceOf(alice);
        assertEq(mSpellBalance, 0);

        deal(spell, alice, 10_000 ether);

        pushPrank(alice);
        spell.safeApprove(address(stakingHub), 10_000 ether);
        stakingHub.deposit(10_000 ether);

        assertEq(stakingHub.balanceOf(alice), 10_000 ether);

        vm.expectRevert(abi.encodeWithSignature("ErrLockedUp()"));
        stakingHub.withdraw(1000 ether);

        pushPrank(stakingHub.owner());
        stakingHub.setToggleLockUp(false);
        popPrank();

        stakingHub.withdraw(1000 ether);

        assertEq(stakingHub.balanceOf(alice), 9000 ether);
        popPrank();
    }

    function testCannotTransferMSpell() public {
        deal(spell, alice, 10_000 ether);

        pushPrank(alice);
        spell.safeApprove(address(stakingHub), 10_000 ether);
        stakingHub.deposit(10_000 ether);

        vm.expectRevert(abi.encodeWithSignature("ErrUnsupportedOperation()"));
        stakingHub.transfer(bob, 1000 ether);

        popPrank();
    }

    function testCannotApproveMSpell() public {
        deal(spell, alice, 10_000 ether);

        pushPrank(alice);
        spell.safeApprove(address(stakingHub), 10_000 ether);
        stakingHub.deposit(10_000 ether);

        vm.expectRevert(abi.encodeWithSignature("ErrUnsupportedOperation()"));
        stakingHub.approve(bob, 1000 ether);

        popPrank();
    }

    function testCannotTransferFromMSpell() public {
        deal(spell, alice, 10_000 ether);

        pushPrank(alice);
        spell.safeApprove(address(stakingHub), 10_000 ether);
        stakingHub.deposit(10_000 ether);

        vm.expectRevert(abi.encodeWithSignature("ErrUnsupportedOperation()"));
        stakingHub.transferFrom(alice, bob, 1000 ether);

        popPrank();
    }

    function testCannotPermitMSpell() public {
        deal(spell, alice, 10_000 ether);

        pushPrank(alice);
        spell.safeApprove(address(stakingHub), 10_000 ether);
        stakingHub.deposit(10_000 ether);

        vm.expectRevert(abi.encodeWithSignature("ErrUnsupportedOperation()"));
        stakingHub.permit(alice, bob, 1000 ether, 0, 0, 0, 0);

        popPrank();
    }

    function testReceiveDepositFromSpoke() public {
        bytes memory data = abi.encode(MessageType.Deposit, alice, 1000 ether);
        uint gasUsed = LayerZeroTestLib.simulateLzReceive(ChainId.Mainnet, ChainId.Arbitrum, address(stakingHub), data);

        assertLt(gasUsed, LZ_RECEIVE_GAS_LIMIT, "Too much gas used compared to configured limit");
    }
}
