// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import {MagicLP} from "/mimswap/MagicLP.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FeeRateModel} from "/mimswap/auxiliary/FeeRateModel.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {WETH} from "solady/tokens/WETH.sol";

contract MagicLPTest is BaseTest {
    using SafeTransferLib for address;

    ERC20Mock mim;
    ERC20Mock usdt;

    FeeRateModel feeRateModel;
    MagicLP lp;

    function setUp() public override {
        vm.chainId(ChainId.Blast);
        super.setUp();

        mim = new ERC20Mock("MIM", "MIM");
        usdt = new ERC20Mock("USDT", "USDT");
        feeRateModel = new FeeRateModel(0, address(0));
        lp = new MagicLP();

        lp.init(address(0), address(mim), address(usdt), 0, address(feeRateModel), 1_000_000, 500000000000000);
    }

    function testAddLiquiditySwap() public {
        assertEq(lp.balanceOf(alice), 0);
        mim.mint(address(lp), 1000 ether);
        usdt.mint(address(lp), 1000 ether);
        lp.buyShares(alice);
        assertNotEq(lp.balanceOf(alice), 0);

        assertEq(usdt.balanceOf(bob), 0);
        mim.mint(address(lp), 50 ether);
        lp.sellBase(bob);
        assertNotEq(usdt.balanceOf(bob), 0);

        assertEq(mim.balanceOf(bob), 0);
        uint256 balance = usdt.balanceOf(bob);
        vm.prank(bob);
        usdt.transfer(address(lp), balance);
        lp.sellQuote(bob);
        assertApproxEqRel(mim.balanceOf(bob), 50 ether, 0.0001e18);

        assertEq(lp.name(), "MagicLP MIM/USDT");
    }
}
