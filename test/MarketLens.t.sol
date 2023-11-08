// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MarketLens.s.sol";

// import "forge-std/console2.sol";

contract MarketLensTest is BaseTest {
    MarketLens lens;

    function setUp() public override {
        fork(ChainId.Mainnet, 16546558);
        _setUp();
    }

    function _setUp() public {
        super.setUp();

        MarketLensScript script = new MarketLensScript();
        script.setTesting(true);
        (lens) = script.deploy();
    }

    function _setUpArbitrum() public {
        fork(ChainId.Arbitrum, 58431441);
        _setUp();
    }

    function testGetBorrowFee() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "Stargate-USDT", 3);
        uint256 response = lens.getBorrowFee(ICauldronV3(cauldronAddress));
        assertEq(response, 0);
    }

    function testGetMaximumCollateralRatio() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "Stargate-USDT", 3);
        uint256 response = lens.getMaximumCollateralRatio(ICauldronV3(cauldronAddress));
        assertEq(response, 9800);
    }

    function testGetLiquidationFee() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "Stargate-USDT", 3);
        uint256 response = lens.getLiquidationFee(ICauldronV3(cauldronAddress));
        assertEq(response, 50);
    }

    function testGetInterestPerYear() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "xSUSHI", 2);
        uint64 response = lens.getInterestPerYear(ICauldronV2(cauldronAddress));
        assertEq(response, 50);
    }

    function testGetMaxUserBorrowForCauldronV2() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "xSUSHI", 2);
        uint256 response = lens.getMaxUserBorrowForCauldronV2(ICauldronV2(cauldronAddress));
        assertEq(response, 161565931473182500204);
    }

    function testGetMaxUserBorrowForCauldronV3() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "CRV", 4);
        uint256 response = lens.getMaxUserBorrowForCauldronV3(ICauldronV3(cauldronAddress));
        assertEq(response, 0);
    }

    function testGetMaxMarketBorrowForCauldronV3() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "Stargate-USDT", 3);
        uint256 response = lens.getMaxMarketBorrowForCauldronV3(ICauldronV3(cauldronAddress));
        assertEq(response, 0);

        address cauldronAddress2 = toolkit.cauldronAddressMap(ChainId.Mainnet, "CRV", 4);
        uint256 response2 = lens.getMaxMarketBorrowForCauldronV3(ICauldronV3(cauldronAddress2));
        assertEq(response2, 0);

        address cauldronAddress3 = toolkit.cauldronAddressMap(ChainId.Mainnet, "yv-3Crypto", 4);
        uint256 response3 = lens.getMaxMarketBorrowForCauldronV3(ICauldronV3(cauldronAddress3));
        assertEq(response3, 0);
    }

    function testGetTotalBorrowed() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "Stargate-USDT", 3);
        uint256 response = lens.getTotalBorrowed(ICauldronV3(cauldronAddress));
        assertEq(response, 7737707438023954991260446);
    }

    function testGetOracleExchangeRate() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "Stargate-USDT", 3);
        uint256 response = lens.getOracleExchangeRate(ICauldronV3(cauldronAddress));
        assertEq(response, 998724);
    }

    function testGetCollateralPrice() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "Stargate-USDT", 3);
        uint256 response = lens.getCollateralPrice(ICauldronV3(cauldronAddress));
        assertEq(response, 1001277);

        address cauldronAddress2 = toolkit.cauldronAddressMap(ChainId.Mainnet, "xSUSHI", 2);
        uint256 response2 = lens.getCollateralPrice(ICauldronV3(cauldronAddress2));
        assertEq(response2, 2062011511089221045);
    }

    function testGetTotalCollateral() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "Stargate-USDT", 3);
        MarketLens.AmountValue memory result = lens.getTotalCollateral(ICauldronV3(cauldronAddress));
        assertEq(result.amount, 8239871142630);
        assertEq(result.value, 8250398651309070373796964);
    }

    function testGetUserBorrow() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "Stargate-USDT", 3);
        uint256 response = lens.getUserBorrow(ICauldronV3(cauldronAddress), 0x1e121993b4A8bC79D18A4C409dB84c100FFf25F5);
        assertEq(response, 2446086936191199212832065);
    }

    function testGetUserCollateral() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "Stargate-USDT", 3);
        MarketLens.AmountValue memory result = lens.getUserCollateral(
            ICauldronV3(cauldronAddress),
            0x1e121993b4A8bC79D18A4C409dB84c100FFf25F5
        );
        assertEq(result.amount, 2542509390600);
        assertEq(result.value, 2545757777524120778112872);
    }

    function testGetUserLtv() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "Stargate-USDT", 3);
        uint256 response = lens.getUserLtv(ICauldronV3(cauldronAddress), 0x1e121993b4A8bC79D18A4C409dB84c100FFf25F5);
        assertEq(response, 9608);

        address shibCauldron = toolkit.cauldronAddressMap(ChainId.Mainnet, "SHIB", 2);
        uint256 shibResponse = lens.getUserLtv(ICauldronV2(shibCauldron), 0x61eC5aDc3De8113ba15a81294138d811943C4f43);
        assertEq(shibResponse, 3854);
    }

    function testGetHealthFactor() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "Stargate-USDT", 3);
        uint256 response = lens.getHealthFactor(ICauldronV3(cauldronAddress), 0x1e121993b4A8bC79D18A4C409dB84c100FFf25F5, false);
        assertEq(response, 19542661960000000);
    }

    function testGetHealthFactorForStable() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "Stargate-USDT", 3);
        uint256 response = lens.getHealthFactor(ICauldronV3(cauldronAddress), 0x1e121993b4A8bC79D18A4C409dB84c100FFf25F5, true);
        assertEq(response, 195426619600000000);
    }

    function testGetHealthFactorForVolatile() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "WBTC", 4);
        uint256 response = lens.getHealthFactor(ICauldronV3(cauldronAddress), 0x8a2Ec1337217Dc52de95230a2979A408E7B4D78E, false);
        assertEq(response, 533905941397697800);
    }

    function testGetUserLiquidationPrice() public {
        // WBTC cauldron with some active user
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "WBTC", 4);
        uint256 price = lens.getUserLiquidationPrice(ICauldronV2(cauldronAddress), 0x8a2Ec1337217Dc52de95230a2979A408E7B4D78E);
        assertApproxEqAbs(price, 1096950008478, 10);

        address cauldronAddress2 = toolkit.cauldronAddressMap(ChainId.Mainnet, "Stargate-USDT", 3);
        uint256 response2 = lens.getUserLiquidationPrice(ICauldronV3(cauldronAddress2), 0x1e121993b4A8bC79D18A4C409dB84c100FFf25F5);
        assertEq(response2, 981710);
    }

    function testGetUserPosition() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "Stargate-USDT", 3);
        MarketLens.UserPosition memory response = lens.getUserPosition(
            ICauldronV3(cauldronAddress),
            0x1e121993b4A8bC79D18A4C409dB84c100FFf25F5
        );

        assertEq(response.account, 0x1e121993b4A8bC79D18A4C409dB84c100FFf25F5);
        assertEq(response.ltvBps, 9608);
    }

    function testGetUserPositionForNoPosition() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "Stargate-USDT", 3);
        MarketLens.UserPosition memory response = lens.getUserPosition(
            ICauldronV3(cauldronAddress),
            0x1111111111111111111111111111111111111111
        );

        assertEq(response.account, 0x1111111111111111111111111111111111111111);
        assertEq(response.ltvBps, 0);
        assertEq(response.healthFactor, 0);
        assertEq(response.borrowValue, 0);
        assertEq(response.collateral.value, 0);
        assertEq(response.collateral.amount, 0);
        assertEq(response.liquidationPrice, 0);
    }

    function testGetMarketInfoCauldronV3() public {
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Mainnet, "Stargate-USDT", 3);
        MarketLens.MarketInfo memory response = lens.getMarketInfoCauldronV3(ICauldronV3(cauldronAddress));

        assertEq(response.cauldron, 0xc6B2b3fE7c3D7a6f823D9106E22e66660709001e);
        assertEq(response.marketMaxBorrow, 0);
        assertEq(response.userMaxBorrow, 0);
    }

    function testGetUserMaxBorrow() public {
        _setUpArbitrum();
        address cauldronAddress = toolkit.cauldronAddressMap(ChainId.Arbitrum, "magicGLP", 4);
        uint256 result = lens.getUserMaxBorrow(ICauldronV3(cauldronAddress), 0x890DaB90D84a9e99f84EcA180f78282a41fD0227);
        assertEq(result, 165803789557656795371284);
    }
}
