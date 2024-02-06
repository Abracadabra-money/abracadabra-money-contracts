// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/Blast.s.sol";

import {ERC20WithBellsMock} from "./mocks/ERC20WithBellsMock.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";
import {IDegenBoxBlast} from "mixins/DegenBoxBlast.sol";
import {OperatableV3} from "mixins/OperatableV3.sol";
import {BlastMock} from "utils/mocks/BlastMock.sol";

contract BlastTest is BaseTest {
    event LogNativeYieldHarvested(address indexed token, uint256 amount);

    address blastBox;
    ERC20WithBellsMock token;
    address constant BLAST_YIELD_PRECOMPILE = 0x0000000000000000000000000000000000000100;

    function setUp() public override {
        //fork(ChainId.Blast, 409770);
        vm.chainId(ChainId.Blast);
        super.setUp();

        BlastScript script = new BlastScript();
        script.setTesting(true);

        (blastBox) = script.deploy();

        pushPrank(alice);
        token = new ERC20WithBellsMock(100_000 ether, 18, "WETH");
        token.transfer(bob, 100 ether);
        popPrank();

        pushPrank(BoringOwnable(blastBox).owner());
        OperatableV3(blastBox).setOperator(alice, true);
        popPrank();
    }

    function testClaimaible() public {
        return;
        pushPrank(bob);
        token.approve(blastBox, 100 ether);
        IBentoBoxV1(blastBox).deposit(token, bob, bob, 100 ether, 0);
        popPrank();

        uint256 shareBefore = IBentoBoxV1(blastBox).balanceOf(token, bob);
        uint256 amountBefore = IBentoBoxV1(blastBox).toAmount(token, shareBefore, false);

        pushPrank(blastBox);
        assertEq(BlastMock(BLAST_YIELD_PRECOMPILE).readClaimableYield(address(token)), 0, "claimable yield should be 0");
        popPrank();

        pushPrank(blastBox);
        BlastMock(BLAST_YIELD_PRECOMPILE).setClaimableAmount(blastBox, address(token), 100 ether);
        assertEq(BlastMock(BLAST_YIELD_PRECOMPILE).readClaimableYield(address(token)), 100 ether);
        popPrank();

        pushPrank(alice);
        token.transfer(BLAST_YIELD_PRECOMPILE, 100 ether); // simulate yield
        vm.expectEmit(true, true, true, true);
        emit LogNativeYieldHarvested(address(token), 100 ether);
        IDegenBoxBlast(blastBox).claimTokenYields(address(token), 100 ether);
        popPrank();

        pushPrank(blastBox);
        assertEq(BlastMock(BLAST_YIELD_PRECOMPILE).readClaimableYield(address(token)), 0);
        popPrank();

        uint256 shareAfter = IBentoBoxV1(blastBox).balanceOf(token, bob);
        uint256 amountAfter = IBentoBoxV1(blastBox).toAmount(token, shareBefore, false);

        assertEq(shareAfter, shareBefore); // no change for the share amount
        assertEq(amountAfter, amountBefore + 100 ether); // underlying amount increased
    }
}
