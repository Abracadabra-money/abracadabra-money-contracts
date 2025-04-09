// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {GMSwapper, IExchangeRouter, IDataStore} from "/swappers/GMSwapper.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import "utils/BaseTest.sol";

contract GMSwapperTest is BaseTest {
    using SafeTransferLib for address;
    IBentoBoxLite box;
    GMSwapper gmSwapper;

    function setUp() public override {
        fork(ChainId.Arbitrum, 319526140);
        super.setUp();

        box = IBentoBoxLite(toolkit.getAddress("degenBox"));
        gmSwapper = new GMSwapper(
            box,
            toolkit.getAddress("mim"),
            IExchangeRouter(toolkit.getAddress("gmx.v2.exchangeRouter")),
            toolkit.getAddress("gmx.v2.syntheticsRouter"),
            toolkit.getAddress("gmx.v2.withdrawalVault"),
            IDataStore(toolkit.getAddress("gmx.v2.dataStore"))
        );
    }

    function testTwoSidedSwap() public {
        vm.txGasPrice(0.01 gwei);
        address market = toolkit.getAddress("gmx.v2.gmBTC");
        uint256 amount = 100 ether;
        deal(market, alice, amount, true);
        vm.prank(alice);
        market.safeApprove(address(box), amount);
        vm.prank(alice);
        (, uint256 share) = box.deposit(market, alice, address(gmSwapper), amount, 0);

        address[] memory oracleTokens = new address[](3);
        oracleTokens[0] = 0x47904963fc8b2340414262125aF798B9655E58Cd; // BTC
        oracleTokens[1] = toolkit.getAddress("wbtc");
        oracleTokens[2] = toolkit.getAddress("usdc");
        address[] memory oracleProviders = new address[](3);
        oracleProviders[0] = 0x527FB0bCfF63C47761039bB386cFE181A92a4701;
        oracleProviders[1] = 0x527FB0bCfF63C47761039bB386cFE181A92a4701;
        oracleProviders[2] = 0x527FB0bCfF63C47761039bB386cFE181A92a4701;
        bytes[] memory oracleData = new bytes[](3);
        oracleData[0] = "";
        oracleData[1] = "";
        oracleData[2] = "";
        IExchangeRouter.SetPricesParams memory setPricesParams = IExchangeRouter.SetPricesParams({
            tokens: oracleTokens,
            providers: oracleProviders,
            data: oracleData
        });

        bytes memory wbtcSwap = bytes.concat(
            hex"2213bc0b000000000000000000000000b254ee265261675528bddb0796741c0c65a4c1580000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f000000000000000000000000000000000000000000000000000000000000c350000000000000000000000000b254ee265261675528bddb0796741c0c65a4c15800000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000007441fff991f000000000000000000000000",
            abi.encodePacked(address(gmSwapper)),
            hex"000000000000000000000000fea7a6a0b346362bf88a9e4a88416b77a57d6c2a0000000000000000000000000000000000000000000000025d7f2535a15ddab000000000000000000000000000000000000000000000000000000000000000a0d410c20060ec3a5b7c1a15d900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000380000000000000000000000000000000000000000000000000000000000000052000000000000000000000000000000000000000000000000000000000000000e4c1fb425e000000000000000000000000b254ee265261675528bddb0796741c0c65a4c1580000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f000000000000000000000000000000000000000000000000000000000000c35000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000067e32b1c00000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001a438c9c1470000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f00000000000000000000000000000000000000000000000000000000000027100000000000000000000000004c4af8dbc524681930a27b2f1af5bcc8062e6fb7000000000000000000000000000000000000000000000000000000000000004400000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000c47dc203820000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc8000000000000000000000000000000000000000000000000000000000000c3500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b254ee265261675528bddb0796741c0c65a4c1580000000000000000000000005e01d320e95133d80dd59a2191c95728fa69036d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000016438c9c147000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc8000000000000000000000000000000000000000000000000000000000000271000000000000000000000000030df229cefa463e991e29d42db0bae2e122b2ac7000000000000000000000000000000000000000000000000000000000000004400000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000084a6417ed600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012438c9c147000000000000000000000000fea7a6a0b346362bf88a9e4a88416b77a57d6c2a000000000000000000000000000000000000000000000000000000000000000f000000000000000000000000fea7a6a0b346362bf88a9e4a88416b77a57d6c2a000000000000000000000000000000000000000000000000000000000000002400000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000044a9059cbb000000000000000000000000ad01c20d5886137e056775af56915de824c8fce50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        );
        GMSwapper.SwapData[] memory swapData = new GMSwapper.SwapData[](2);
        swapData[0] = GMSwapper.SwapData({
            token: toolkit.getAddress("wbtc"),
            to: 0x0000000000001fF3684f28c67538d4D072C22734,
            data: wbtcSwap
        });
        bytes memory usdcSwap = bytes.concat(
            hex"2213bc0b000000000000000000000000b254ee265261675528bddb0796741c0c65a4c158000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e58310000000000000000000000000000000000000000000000000000000002625a00000000000000000000000000b254ee265261675528bddb0796741c0c65a4c15800000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000004241fff991f000000000000000000000000",
            abi.encodePacked(address(gmSwapper)),
            hex"000000000000000000000000fea7a6a0b346362bf88a9e4a88416b77a57d6c2a00000000000000000000000000000000000000000000000229fd0147dbf19bac00000000000000000000000000000000000000000000000000000000000000a008e202a6a1295c07d79db3670000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000018422ce6ede000000000000000000000000b254ee265261675528bddb0796741c0c65a4c1580000000000000000000000000000000000000000000000000000000000000100000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e58310000000000000000000000000000000000000000000000000000000002625a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000067e32b1a00000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002caf88d065e77c8cc2239327c5edb3a432268e583101000064fea7a6a0b346362bf88a9e4a88416b77a57d6c2a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012438c9c147000000000000000000000000fea7a6a0b346362bf88a9e4a88416b77a57d6c2a000000000000000000000000000000000000000000000000000000000000000f000000000000000000000000fea7a6a0b346362bf88a9e4a88416b77a57d6c2a000000000000000000000000000000000000000000000000000000000000002400000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000044a9059cbb000000000000000000000000ad01c20d5886137e056775af56915de824c8fce50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        );
        swapData[1] = GMSwapper.SwapData({
            token: toolkit.getAddress("usdc"),
            to: 0x0000000000001fF3684f28c67538d4D072C22734,
            data: usdcSwap
        });
        uint256 executionFee = 0.001 ether;
        vm.deal(alice, 0);
        vm.prank(alice);
        gmSwapper.swap{value: executionFee}(
            market,
            toolkit.getAddress("mim"),
            alice,
            70 ether,
            share,
            abi.encode(swapData, setPricesParams)
        );
        // Assert all gas was refunded
        assertEq(address(gmSwapper).balance, 0);
        assertEq(alice.balance, executionFee);
    }

    function testSingleSidedSwap() public {
        vm.txGasPrice(0.01 gwei);
        address market = toolkit.getAddress("gmx.v2.gmBTCSingleSided");
        uint256 amount = 50 ether;
        deal(market, alice, amount, true);
        vm.prank(alice);
        market.safeApprove(address(box), amount);
        vm.prank(alice);
        (, uint256 share) = box.deposit(market, alice, address(gmSwapper), amount, 0);

        address[] memory oracleTokens = new address[](2);
        oracleTokens[0] = 0x47904963fc8b2340414262125aF798B9655E58Cd; // BTC
        oracleTokens[1] = toolkit.getAddress("wbtc");
        address[] memory oracleProviders = new address[](2);
        oracleProviders[0] = 0x527FB0bCfF63C47761039bB386cFE181A92a4701;
        oracleProviders[1] = 0x527FB0bCfF63C47761039bB386cFE181A92a4701;
        bytes[] memory oracleData = new bytes[](2);
        oracleData[0] = "";
        oracleData[1] = "";
        IExchangeRouter.SetPricesParams memory setPricesParams = IExchangeRouter.SetPricesParams({
            tokens: oracleTokens,
            providers: oracleProviders,
            data: oracleData
        });

        bytes memory wbtcSwap = bytes.concat(
            hex"2213bc0b000000000000000000000000b254ee265261675528bddb0796741c0c65a4c1580000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f000000000000000000000000000000000000000000000000000000000000c350000000000000000000000000b254ee265261675528bddb0796741c0c65a4c15800000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000007441fff991f000000000000000000000000",
            abi.encodePacked(address(gmSwapper)),
            hex"000000000000000000000000fea7a6a0b346362bf88a9e4a88416b77a57d6c2a0000000000000000000000000000000000000000000000025d7f2535a15ddab000000000000000000000000000000000000000000000000000000000000000a0d410c20060ec3a5b7c1a15d900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000380000000000000000000000000000000000000000000000000000000000000052000000000000000000000000000000000000000000000000000000000000000e4c1fb425e000000000000000000000000b254ee265261675528bddb0796741c0c65a4c1580000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f000000000000000000000000000000000000000000000000000000000000c35000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000067e32b1c00000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001a438c9c1470000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f00000000000000000000000000000000000000000000000000000000000027100000000000000000000000004c4af8dbc524681930a27b2f1af5bcc8062e6fb7000000000000000000000000000000000000000000000000000000000000004400000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000c47dc203820000000000000000000000002f2a2543b76a4166549f7aab2e75bef0aefc5b0f000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc8000000000000000000000000000000000000000000000000000000000000c3500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b254ee265261675528bddb0796741c0c65a4c1580000000000000000000000005e01d320e95133d80dd59a2191c95728fa69036d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000016438c9c147000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc8000000000000000000000000000000000000000000000000000000000000271000000000000000000000000030df229cefa463e991e29d42db0bae2e122b2ac7000000000000000000000000000000000000000000000000000000000000004400000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000084a6417ed600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012438c9c147000000000000000000000000fea7a6a0b346362bf88a9e4a88416b77a57d6c2a000000000000000000000000000000000000000000000000000000000000000f000000000000000000000000fea7a6a0b346362bf88a9e4a88416b77a57d6c2a000000000000000000000000000000000000000000000000000000000000002400000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000044a9059cbb000000000000000000000000ad01c20d5886137e056775af56915de824c8fce50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        );
        GMSwapper.SwapData[] memory swapData = new GMSwapper.SwapData[](1);
        swapData[0] = GMSwapper.SwapData({
            token: toolkit.getAddress("wbtc"),
            to: 0x0000000000001fF3684f28c67538d4D072C22734,
            data: wbtcSwap
        });
        uint256 executionFee = 0.001 ether;
        vm.deal(alice, 0);
        vm.prank(alice);
        gmSwapper.swap{value: executionFee}(
            market,
            toolkit.getAddress("mim"),
            alice,
            35 ether,
            share,
            abi.encode(swapData, setPricesParams)
        );
        // Assert all gas was refunded
        assertEq(address(gmSwapper).balance, 0);
        assertEq(alice.balance, executionFee);
    }
}
