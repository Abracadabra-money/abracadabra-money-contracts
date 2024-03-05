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
import {BlastTokenRegistry} from "/blast/BlastTokenRegistry.sol";

contract BlastTest is BaseTest {
    using SafeTransferLib for address;

    event LogBlastGasClaimed(address indexed recipient, uint256 amount);
    event LogBlastETHClaimed(address indexed recipient, uint256 amount);
    event LogBlastTokenClaimed(address indexed recipient, address indexed token, uint256 amount);
    event LogBlastTokenClaimableEnabled(address indexed contractAddress, address indexed token);
    event LogBlastNativeClaimableEnabled(address indexed contractAddress);

    address blastBox;
    address constant BLAST_YIELD_PRECOMPILE = 0x4300000000000000000000000000000000000002;
    IERC20 weth;
    IERC20 usdb;

    BlastTokenRegistry blastBoxTokenRegistry;
    address blastBoxFeeTo;

    function setUp() public override {
        fork(ChainId.Blast, 203996);
        super.setUp();
        BlastMock(BLAST_YIELD_PRECOMPILE).enableYieldTokenMocks();

        BlastScript script = new BlastScript();
        script.setTesting(true);

        (blastBox) = script.deploy();

        weth = IERC20(toolkit.getAddress(ChainId.Blast, "weth"));
        usdb = IERC20(toolkit.getAddress(ChainId.Blast, "usdb"));

        blastBoxFeeTo = IBlastBox(blastBox).feeTo();
        blastBoxTokenRegistry = BlastTokenRegistry(IBlastBox(blastBox).registry());

        pushPrank(blastBoxTokenRegistry.owner());
        blastBoxTokenRegistry.setNativeYieldTokenEnabled(address(weth), true);
        blastBoxTokenRegistry.setNativeYieldTokenEnabled(address(usdb), true);
        popPrank();

        pushPrank(BoringOwnable(blastBox).owner());
        OperatableV3(blastBox).setOperator(alice, true);
        IBlastBox(blastBox).setTokenEnabled(address(weth), true);
        IBlastBox(blastBox).setTokenEnabled(address(usdb), true);
        popPrank();
    }

    function testDepositEnabledTokensOnly() public {
        pushPrank(BoringOwnable(blastBox).owner());
        IBlastBox(blastBox).setTokenEnabled(address(usdb), false);
        popPrank();

        deal(address(usdb), bob, 100e6, true);
        pushPrank(bob);
        address(usdb).safeApprove(blastBox, 100e6);

        vm.expectRevert(abi.encodeWithSignature("ErrUnsupportedToken()"));
        IBentoBoxV1(blastBox).deposit(usdb, bob, bob, 100e6, 0);
        popPrank();

        assertEq(IBentoBoxV1(blastBox).balanceOf(usdb, bob), 0 ether);

        pushPrank(BoringOwnable(blastBox).owner());
        IBlastBox(blastBox).setTokenEnabled(address(usdb), true);
        popPrank();

        pushPrank(bob);
        IBentoBoxV1(blastBox).deposit(usdb, bob, bob, 100e6, 0);
        popPrank();

        assertEq(IBentoBoxV1(blastBox).balanceOf(usdb, bob), 100e6);
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
        emit LogBlastGasClaimed(blastBoxFeeTo, 1 ether);
        IBlastBox(blastBox).claimGasYields();
        popPrank();

        uint256 shareAfter = IBentoBoxV1(blastBox).balanceOf(weth, bob);
        uint256 amountAfter = IBentoBoxV1(blastBox).toAmount(weth, shareBefore, false);

        assertEq(shareAfter, shareBefore); // no change
        assertEq(amountAfter, amountBefore); // no change
    }

    function testTokenClaim() public {
        _testTokenClaim(usdb);
        _testTokenClaim(weth);
    }

    function _testTokenClaim(IERC20 token) private {
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
        emit LogBlastTokenClaimed(blastBoxFeeTo, address(token), 1 ether);
        IBlastBox(blastBox).claimTokenYields(address(token));
        popPrank();

        pushPrank(blastBox);
        assertEq(BlastMock(BLAST_YIELD_PRECOMPILE).readClaimableYield(address(blastBox)), 0);
        popPrank();

        uint256 shareAfter = IBentoBoxV1(blastBox).balanceOf(token, bob);
        uint256 amountAfter = IBentoBoxV1(blastBox).toAmount(token, shareBefore, false);

        assertEq(shareAfter, shareBefore); // no change
        assertEq(amountAfter, amountBefore); // no change
    }
}
