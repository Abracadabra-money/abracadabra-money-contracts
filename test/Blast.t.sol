// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/Blast.s.sol";

import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";
import {IBlastBox} from "/blast/interfaces/IBlastBox.sol";
import {OperatableV3} from "mixins/OperatableV3.sol";
import {BlastMock, BlastTokenMock} from "utils/mocks/BlastMock.sol";
import {BlastBox} from "/blast/BlastBox.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";

contract BlastTest is BaseTest {
    using SafeTransferLib for address;

    event LogBlastETHClaimed(uint256 amount);
    event LogBlastGasClaimed(uint256 amount);
    event LogBlastTokenClaimed(address indexed token, uint256 amount);
    event LogBlastYieldAdded(address indexed token, uint256 userAmount, uint256 feeAmount);
    event LogBlastYieldTokenEnabled(address indexed token, bool previous, bool current);

    address blastBox;
    address constant BLAST_YIELD_PRECOMPILE = 0x4300000000000000000000000000000000000002;
    IERC20 weth;
    IERC20 usdb;

    function setUp() public override {
        //fork(ChainId.Blast, 409770);
        vm.chainId(ChainId.Blast);
        super.setUp();

        BlastScript script = new BlastScript();
        script.setTesting(true);

        (blastBox) = script.deploy();

        weth = IERC20(toolkit.getAddress(ChainId.Blast, "weth"));
        usdb = IERC20(toolkit.getAddress(ChainId.Blast, "usdb"));

        pushPrank(BoringOwnable(blastBox).owner());
        OperatableV3(blastBox).setOperator(alice, true);
        IBlastBox(blastBox).setTokenEnabled(address(weth), true, true);
        IBlastBox(blastBox).setTokenEnabled(address(usdb), true, true);
        popPrank();
    }

    function testDepositEnabledTokensOnly() public {
        pushPrank(BoringOwnable(blastBox).owner());
        IBlastBox(blastBox).setTokenEnabled(address(usdb), false, true);
        popPrank();

        deal(address(usdb), bob, 100e6, true);
        pushPrank(bob);
        address(usdb).safeApprove(blastBox, 100e6);

        vm.expectRevert(abi.encodeWithSignature("ErrTokenNotEnabled()"));
        IBentoBoxV1(blastBox).deposit(usdb, bob, bob, 100e6, 0);
        popPrank();

        assertEq(IBentoBoxV1(blastBox).balanceOf(usdb, bob), 0 ether);

        pushPrank(BoringOwnable(blastBox).owner());
        IBlastBox(blastBox).setTokenEnabled(address(usdb), true, true);
        popPrank();

        pushPrank(bob);
        IBentoBoxV1(blastBox).deposit(usdb, bob, bob, 100e6, 0);
        popPrank();

        assertEq(IBentoBoxV1(blastBox).balanceOf(usdb, bob), 100e6);
    }

    function testClaimableETH() public {
        pushPrank(bob);
        deal(address(weth), bob, 100 ether, true);
        address(weth).safeApprove(blastBox, 100 ether);
        IBentoBoxV1(blastBox).deposit(weth, bob, bob, 100 ether, 0);
        popPrank();

        uint256 shareBefore = IBentoBoxV1(blastBox).balanceOf(weth, bob);
        uint256 amountBefore = IBentoBoxV1(blastBox).toAmount(weth, shareBefore, false);

        pushPrank(blastBox);
        assertEq(BlastMock(BLAST_YIELD_PRECOMPILE).readClaimableYield(address(weth)), 0, "claimable yield should be 0");
        popPrank();

        pushPrank(blastBox);
        BlastMock(BLAST_YIELD_PRECOMPILE).addClaimable(blastBox, 100 ether);
        assertEq(BlastMock(BLAST_YIELD_PRECOMPILE).readClaimableYield(address(blastBox)), 100 ether);
        popPrank();

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogBlastETHClaimed(100 ether);
        emit LogBlastYieldAdded(address(weth), 100 ether, 0);
        IBlastBox(blastBox).claimETHYields(100 ether);
        popPrank();

        pushPrank(blastBox);
        assertEq(BlastMock(BLAST_YIELD_PRECOMPILE).readClaimableYield(address(blastBox)), 0);
        popPrank();

        uint256 shareAfter = IBentoBoxV1(blastBox).balanceOf(weth, bob);
        uint256 amountAfter = IBentoBoxV1(blastBox).toAmount(weth, shareBefore, false);

        assertEq(shareAfter, shareBefore); // no change for the share amount
        assertEq(amountAfter, amountBefore + 100 ether); // underlying amount increased
    }

    function testClaimableGas() public {
        pushPrank(bob);
        deal(address(weth), bob, 1 ether, true);
        address(weth).safeApprove(blastBox, 1 ether);
        IBentoBoxV1(blastBox).deposit(weth, bob, bob, 1 ether, 0);
        popPrank();

        uint256 shareBefore = IBentoBoxV1(blastBox).balanceOf(weth, bob);
        uint256 amountBefore = IBentoBoxV1(blastBox).toAmount(weth, shareBefore, false);

        BlastMock(BLAST_YIELD_PRECOMPILE).addClaimableGas(blastBox, 1 ether);

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogBlastGasClaimed(1 ether);
        emit LogBlastYieldAdded(address(weth), 1 ether, 0);
        IBlastBox(blastBox).claimGasYields();
        popPrank();

        uint256 shareAfter = IBentoBoxV1(blastBox).balanceOf(weth, bob);
        uint256 amountAfter = IBentoBoxV1(blastBox).toAmount(weth, shareBefore, false);

        assertEq(shareAfter, shareBefore); // no change for the share amount
        assertEq(amountAfter, amountBefore + 1 ether); // underlying amount increased
    }

    function testTokenClaim() public {
        _testTokenClaim(usdb);
        _testTokenClaim(weth);
    }

    function _testTokenClaim(IERC20 token) private {
        // For testnet, set feeBips to 10_000 to force the claim to be sent to the feeCollector
        // because it doesn't support claiming to the same address
        pushPrank(BoringOwnable(blastBox).owner());
        FeeCollectable(blastBox).setFeeParameters(tx.origin, 10_000);
        popPrank();

        pushPrank(bob);
        deal(address(token), bob, 100 ether, true);
        address(token).safeApprove(blastBox, 100 ether);
        IBentoBoxV1(blastBox).deposit(token, bob, bob, 100 ether, 0);
        popPrank();

        uint256 shareBefore = IBentoBoxV1(blastBox).balanceOf(token, bob);
        uint256 amountBefore = IBentoBoxV1(blastBox).toAmount(token, shareBefore, false);

        pushPrank(blastBox);
        assertEq(BlastMock(BLAST_YIELD_PRECOMPILE).readClaimableYield(address(token)), 0, "claimable yield should be 0");
        popPrank();

        pushPrank(blastBox);
        BlastTokenMock(address(token)).addClaimable(blastBox, 1 ether);
        popPrank();

        pushPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit LogBlastTokenClaimed(address(token), 1 ether);
        IBlastBox(blastBox).claimTokenYields(address(token), 1 ether);
        popPrank();

        pushPrank(blastBox);
        assertEq(BlastMock(BLAST_YIELD_PRECOMPILE).readClaimableYield(address(blastBox)), 0);
        popPrank();

        uint256 shareAfter = IBentoBoxV1(blastBox).balanceOf(token, bob);
        uint256 amountAfter = IBentoBoxV1(blastBox).toAmount(token, shareBefore, false);

        assertEq(shareAfter, shareBefore); // no change for the share amount
        assertEq(amountAfter, amountBefore); // underlying amount stays the same because fee bips is 10_000
    }
}
