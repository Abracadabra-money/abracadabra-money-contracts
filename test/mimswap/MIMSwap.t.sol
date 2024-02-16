// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MIMSwap.s.sol";
import {BlastMagicLP} from "/blast/BlastMagicLP.sol";
import {BlastTokenMock} from "utils/mocks/BlastMock.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract MIMSwapTestBase is BaseTest {
    MagicLP implementation;
    FeeRateModel feeRateModel;
    Registry registry;
    Factory factory;
    Router router;

    function initialize(uint256 chainId, uint256 blockNumber) public returns (MIMSwapScript script) {
        fork(chainId, blockNumber);
        super.setUp();

        script = new MIMSwapScript();
        script.setTesting(true);
    }

    function afterDeployed() public {}
}

contract MIMSwapTest is MIMSwapTestBase {
    using SafeTransferLib for address;

    address constant BLAST_PRECOMPILE = 0x4300000000000000000000000000000000000002;

    address mim;
    address usdb;
    address feeCollector;
    BlastTokenRegistry blastTokenRegistry;

    function setUp() public override {
        MIMSwapScript script = super.initialize(ChainId.Blast, 1714281);
        (implementation, feeRateModel, registry, factory, router) = script.deploy();

        mim = toolkit.getAddress(ChainId.Blast, "mim");
        usdb = toolkit.getAddress(ChainId.Blast, "usdb");

        feeCollector = BlastMagicLP(address(implementation)).feeTo();
        blastTokenRegistry = BlastMagicLP(address(implementation)).registry();

        super.afterDeployed();
    }

    function testOnlyCallableOnClones() public {
        BlastMagicLP lp = _createDefaultLp();
        BlastMagicLP _implementation = lp.implementation();

        vm.expectRevert(abi.encodeWithSignature("ErrNotClone()"));
        _implementation.claimYields();
        vm.expectRevert(abi.encodeWithSignature("ErrNotClone()"));
        _implementation.updateTokenClaimables();

        vm.expectRevert(abi.encodeWithSignature("ErrNotAllowedImplementationOperator()"));
        lp.claimYields();
        vm.expectRevert(abi.encodeWithSignature("ErrNotAllowedImplementationOperator()"));
        lp.updateTokenClaimables();
    }

    function testOnlyCallableOnImplementation() public {
        BlastMagicLP lp = _createDefaultLp();
        BlastMagicLP _implementation = lp.implementation();

        vm.expectRevert(abi.encodeWithSignature("ErrNotImplementation()"));
        lp.setFeeTo(bob);
        vm.expectRevert(abi.encodeWithSignature("ErrNotImplementation()"));
        lp.setOperator(bob, true);

        vm.expectRevert(abi.encodeWithSignature("ErrNotImplementationOwner()"));
        _implementation.setFeeTo(bob);
        vm.expectRevert(abi.encodeWithSignature("ErrNotImplementationOwner()"));
        _implementation.setOperator(bob, true);
    }

    function testClaimYields() public {
        BlastMagicLP lp = _createDefaultLp();
        BlastMagicLP _implementation = lp.implementation();

        pushPrank(_implementation.owner());
        lp.claimYields();
        popPrank();

        // Simulate gas yield
        BlastMock(BLAST_PRECOMPILE).addClaimableGas(address(lp), 1 ether);
        uint256 balanceBefore = feeCollector.balance;

        pushPrank(_implementation.owner());
        lp.claimYields();
        popPrank();
        assertEq(feeCollector.balance, balanceBefore + 1 ether);

        // simulate token yields
        BlastTokenMock(usdb).addClaimable(address(lp), 1 ether);
        balanceBefore = usdb.balanceOf(feeCollector);

        pushPrank(_implementation.owner());
        // Try claiming token yields without enabling claimable on it
        lp.claimYields();

        // Enable claimable on USDB
        pushPrank(blastTokenRegistry.owner());
        blastTokenRegistry.registerNativeYieldToken(usdb);
        popPrank();

        vm.expectRevert(abi.encodeWithSignature("NotClaimableAccount()"));
        lp.claimYields();

        lp.updateTokenClaimables();
        lp.claimYields();
        popPrank();
        assertEq(usdb.balanceOf(feeCollector), balanceBefore + 1 ether);
    }

    function _createDefaultLp() internal returns (BlastMagicLP lp) {
        lp = BlastMagicLP(factory.create(mim, usdb, 80000000000000, 997724689700000000, 100000000000000));

        assertNotEq(address(lp.implementation()), address(0));
        assertEq(lp.feeTo(), address(0));
        assertEq(lp.owner(), address(0));
        assertNotEq(lp.implementation().feeTo(), address(0));
        assertNotEq(lp.implementation().owner(), address(0));
    }
}
