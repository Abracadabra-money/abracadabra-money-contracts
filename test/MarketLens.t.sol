// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MarketLens.s.sol";
import "forge-std/console2.sol";

contract MarketLensTest is BaseTest {
    MarketLens lens;

    function setUp() public override {
        // If I want to run some tests on Mainnet and some tests on Arbitrum, how can I do that?
        forkMainnet(16546558);
        super.setUp();

        MarketLensScript script = new MarketLensScript();
        script.setTesting(true);
        (lens) = script.run();
    }

    function testGetInterestPerYear() public {
        address cauldronAddress = constants.getCauldronAddress("xSUSHI", 2);
        uint64 response = lens.getInterestPerYear(ICauldronV2(cauldronAddress));
        assertEq(response, 50);
    }

    function testGetMaxBorrowForCauldronV2() public {
        address cauldronAddress = constants.getCauldronAddress("xSUSHI", 2);
        uint256 response = lens.getMaxBorrowForCauldronV2(ICauldronV2(cauldronAddress));
        assertEq(response, 161565931473182500204);
    }

    function testGetUserBorrowLimit() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        uint256 response = lens.getUserBorrowLimit(ICauldronV3(cauldronAddress));
        assertEq(response, 10000000000000000000000000);
    }

    function testGetMaxBorrowForCauldronV3() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        uint256 response = lens.getMaxBorrowForCauldronV3(ICauldronV3(cauldronAddress));
        assertEq(response, 0);
    }

    function testGetTotalMimBorrowed() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        uint256 response = lens.getTotalMimBorrowed(ICauldronV3(cauldronAddress));
        assertEq(response, 7737685061156947798839069);
    }

    function testGetTvl() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        uint256 response = lens.getTvl(ICauldronV3(cauldronAddress));
        assertEq(response, 8250398651309070373796964);
    }
}
