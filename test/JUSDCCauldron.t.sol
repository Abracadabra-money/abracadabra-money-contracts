// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/JUSDCCauldron.s.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract JUSDCCauldronTest is BaseTest {
    using SafeTransferLib for address;

    MagicJUSDC mJUSDC;
    MagicJUSDCHarvestor harvestor;
    address jusdc;

    address constant JUSDC_WHALE = 0x8Fec806c9e94ff7AB2AF3D7e4875c2381413f98E;

    function setUp() public override {
        fork(ChainId.Arbitrum, 223908453);
        super.setUp();

        JUSDCCauldronScript script = new JUSDCCauldronScript();
        script.setTesting(true);

        jusdc = toolkit.getAddress(block.chainid, "jones.jusdc");

        (mJUSDC, harvestor) = script.deploy();
    }

    function testHarvesting() public {
        _getMagicJUSDC(100_000 ether, alice);
    }

    function _getMagicJUSDC(uint amount, address to) private {
        pushPrank(JUSDC_WHALE);
        jusdc.safeTransfer(to, amount);
        popPrank();

        pushPrank(to);
        jusdc.safeApprove(address(mJUSDC), amount);
        // enable once STIP2 pool is on
        //mJUSDC.deposit(amount, to);
        popPrank();
    }
}
