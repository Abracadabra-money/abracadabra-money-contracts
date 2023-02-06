// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MarketLens.s.sol";

// import "forge-std/console2.sol";

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

    function testGetBorrowFee() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        uint256 response = lens.getBorrowFee(ICauldronV3(cauldronAddress));
        assertEq(response, 0);
    }

    function testGetMaximumCollateralRatio() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        uint256 response = lens.getMaximumCollateralRatio(ICauldronV3(cauldronAddress));
        assertEq(response, 98000);
    }

    function testGetLiquidationFee() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        uint256 response = lens.getLiquidationFee(ICauldronV3(cauldronAddress));
        assertEq(response, 500);
    }

    function testGetInterestPerYear() public {
        address cauldronAddress = constants.getCauldronAddress("xSUSHI", 2);
        uint64 response = lens.getInterestPerYear(ICauldronV2(cauldronAddress));
        assertEq(response, 50);
    }

    function testGetUserMaxBorrowForCauldronV2() public {
        address cauldronAddress = constants.getCauldronAddress("xSUSHI", 2);
        uint256 response = lens.getMaxBorrowForCauldronV2User(ICauldronV2(cauldronAddress));
        assertEq(response, 161565931473182500204);
    }

    function testGetMarketMaxBorrowForCauldronV3() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        uint256 response = lens.getMaxBorrowForCauldronV3User(ICauldronV3(cauldronAddress));
        assertEq(response, 0);
    }

    function testGetUserMaxBorrowForCauldronV3() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        uint256 response = lens.getMaxBorrowForCauldronV3User(ICauldronV3(cauldronAddress));
        assertEq(response, 0);
    }

    function testGetTotalBorrowed() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        uint256 response = lens.getTotalBorrowed(ICauldronV3(cauldronAddress));
        assertEq(response, 7737707438023954991260446);
    }

    function testGetOracleExchangeRate() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        uint256 response = lens.getOracleExchangeRate(ICauldronV3(cauldronAddress));
        assertEq(response, 998724);
    }

    function testGetCollateralPrice() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        uint256 response = lens.getCollateralPrice(ICauldronV3(cauldronAddress));
        assertEq(response, 1001277630256206920);

        address cauldronAddress2 = constants.getCauldronAddress("xSUSHI", 2);
        uint256 response2 = lens.getCollateralPrice(ICauldronV3(cauldronAddress2));
        assertEq(response2, 2062011511089221045);
    }

    function testGetTotalCollateral() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        MarketLens.AmountValue memory result = lens.getTotalCollateral(ICauldronV3(cauldronAddress));
        assertEq(result.amount, 8239871142630);
        assertEq(result.value, 8250398651309070373796964);
    }

    function testGetUserBorrow() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        uint256 response = lens.getUserBorrow(ICauldronV3(cauldronAddress), 0x1e121993b4A8bC79D18A4C409dB84c100FFf25F5);
        assertEq(response, 2446086936191199212832065);
    }

    function testGetUserCollateral() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        MarketLens.AmountValue memory result = lens.getUserCollateral(
            ICauldronV3(cauldronAddress),
            0x1e121993b4A8bC79D18A4C409dB84c100FFf25F5
        );
        assertEq(result.amount, 2542509390600);
        assertEq(result.value, 2545757777524120778112872);
    }

    function testGetUserLtv() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        uint256 response = lens.getUserLtv(ICauldronV3(cauldronAddress), 0x1e121993b4A8bC79D18A4C409dB84c100FFf25F5);
        assertEq(response, 9608);
    }

    function testGetUserLiquidationPrice() public {
        // WBTC cauldron with some active user
        address cauldronAddress = constants.getCauldronAddress("WBTC", 4);
        uint256 price = lens.getUserLiquidationPrice(ICauldronV2(cauldronAddress), 0x8a2Ec1337217Dc52de95230a2979A408E7B4D78E);
        assertApproxEqAbs(price, 1096950008478, 10);

        address cauldronAddress2 = constants.getCauldronAddress("Stargate-USDT", 3);
        uint256 response2 = lens.getUserLiquidationPrice(ICauldronV3(cauldronAddress2), 0x1e121993b4A8bC79D18A4C409dB84c100FFf25F5);
        assertEq(response2, 981710);
    }

    function testGetUserPosition() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        MarketLens.UserPosition memory response = lens.getUserPosition(
            ICauldronV3(cauldronAddress),
            0x1e121993b4A8bC79D18A4C409dB84c100FFf25F5
        );
        assertEq(response.ltvBps, 9608);
    }

    function testGetMarketInfoCauldronV3() public {
        address cauldronAddress = constants.getCauldronAddress("Stargate-USDT", 3);
        MarketLens.MarketInfo memory response = lens.getMarketInfoCauldronV3(ICauldronV3(cauldronAddress));
        assertEq(response.marketMaxBorrow, 0);
        assertEq(response.userMaxBorrow, 0);
    }
}
