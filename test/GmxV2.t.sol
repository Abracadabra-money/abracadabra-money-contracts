// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/ERC20.sol";
import "utils/BaseTest.sol";
import "script/GmxV2.s.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import "./utils/CauldronTestLib.sol";
import "./mocks/ExchangeRouterMock.sol";
import {ICauldronV4GmxV2} from "interfaces/ICauldronV4GmxV2.sol";
import {IGmRouterOrder, GmRouterOrderParams} from "periphery/GmxV2CauldronOrderAgent.sol";
import {IGmxV2DepositCallbackReceiver, IGmxV2Deposit, IGmxV2EventUtils} from "interfaces/IGmxV2.sol";
import {LiquidationHelper} from "periphery/LiquidationHelper.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {IWETH} from "interfaces/IWETH.sol";

interface DepositHandler {
    struct SetPricesParams {
        uint256 signerInfo;
        address[] tokens;
        uint256[] compactedMinOracleBlockNumbers;
        uint256[] compactedMaxOracleBlockNumbers;
        uint256[] compactedOracleTimestamps;
        uint256[] compactedDecimals;
        uint256[] compactedMinPrices;
        uint256[] compactedMinPricesIndexes;
        uint256[] compactedMaxPrices;
        uint256[] compactedMaxPricesIndexes;
        bytes[] signatures;
        address[] priceFeedTokens;
        address[] realtimeFeedTokens;
        bytes[] realtimeFeedData;
    }

    function executeDeposit(bytes32 key, SetPricesParams calldata oracleParams) external;
}

contract GmxV2Test is BaseTest {
    using SafeTransferLib for address;

    IGmCauldronOrderAgent orderAgent;
    GmxV2Script.MarketDeployment gmETHDeployment;
    GmxV2Script.MarketDeployment gmBTCDeployment;
    GmxV2Script.MarketDeployment gmARBDeployment;

    event LogOrderCanceled(address indexed user, address indexed order);
    event LogAddCollateral(address indexed from, address indexed to, uint256 share);
    error ErrMinOutTooLarge();

    address constant GM_BTC_WHALE = 0x8d16D32f785D0B11fDa5E443FCC39610f91a50A8;
    address constant GM_ETH_WHALE = 0xA329Ac2efFFea563159897d7828866CFaeD42167;
    address constant GM_ARB_WHALE = 0x8E52cA5A7a9249431F03d60D79DDA5EAB4930178;
    address constant MIM_WHALE = 0x27807dD7ADF218e1f4d885d54eD51C70eFb9dE50;
    address constant GMX_EXECUTOR = 0xf1e1B2F4796d984CCb8485d43db0c64B83C1FA6d;

    address gmBTC;
    address gmETH;
    address gmARB;
    address usdc;
    address mim;
    address weth;
    address masterContract;
    IBentoBoxV1 box;
    ExchangeRouterMock exchange;
    IGmxV2ExchangeRouter router;

    function setUp() public override {
        fork(ChainId.Arbitrum, 139685420);
        super.setUp();

        GmxV2Script script = new GmxV2Script();
        script.setTesting(true);

        (masterContract, orderAgent, gmETHDeployment, gmBTCDeployment, gmARBDeployment) = script.deploy();

        box = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        mim = toolkit.getAddress(block.chainid, "mim");
        gmBTC = toolkit.getAddress(block.chainid, "gmx.v2.gmBTC");
        gmETH = toolkit.getAddress(block.chainid, "gmx.v2.gmETH");
        weth = toolkit.getAddress(block.chainid, "weth");
        gmARB = toolkit.getAddress(block.chainid, "gmx.v2.gmARB");
        router = IGmxV2ExchangeRouter(toolkit.getAddress(block.chainid, "gmx.v2.exchangeRouter"));
        usdc = toolkit.getAddress(block.chainid, "usdc");
        exchange = new ExchangeRouterMock(ERC20(address(0)), ERC20(address(0)));

        // Alice just made it
        deal(usdc, alice, 100_000e6);
        pushPrank(GM_BTC_WHALE);
        gmBTC.safeTransfer(alice, 100_000 ether);
        popPrank();
        pushPrank(GM_ETH_WHALE);
        gmETH.safeTransfer(alice, 100_000 ether);
        popPrank();
        pushPrank(GM_ARB_WHALE);
        gmARB.safeTransfer(alice, 100_000 ether);
        popPrank();

        // put 1m mim inside the cauldrons
        pushPrank(MIM_WHALE);
        mim.safeTransfer(address(box), 3_000_000e18);
        popPrank();

        box.deposit(IERC20(mim), address(box), address(gmETHDeployment.cauldron), 1_000_000e18, 0);
        box.deposit(IERC20(mim), address(box), address(gmBTCDeployment.cauldron), 1_000_000e18, 0);
        box.deposit(IERC20(mim), address(box), address(gmARBDeployment.cauldron), 1_000_000e18, 0);

        pushPrank(box.owner());
        box.whitelistMasterContract(masterContract, true);
        popPrank();
    }

    function testOracles() public {
        uint256 price;

        console2.log("=== gmETH OraclePrice ===");
        (, price) = gmETHDeployment.oracle.peek(bytes(""));
        console2.log("price", price);
        assertEq(price, 1089611872333813650);

        console2.log("=== gmBTC OraclePrice ===");
        (, price) = gmBTCDeployment.oracle.peek(bytes(""));
        console2.log("price", price);
        assertEq(price, 1008339991773323838);

        console2.log("=== gmARB OraclePrice ===");
        (, price) = gmARBDeployment.oracle.peek(bytes(""));
        console2.log("price", price);
        assertEq(price, 1189214556682150869);
    }

    /// Borrow: GM token --> MIM
    function testUnleveragedBorrow() public {
        vm.startPrank(alice);
        CauldronTestLib.depositAndBorrow(box, gmETHDeployment.cauldron, masterContract, IERC20(gmETH), alice, 10_000 ether, 50);
        vm.stopPrank();
    }

    /// LeveragedBorrow: GMToken -> MIM -> USDC (using levSwapper) -> ACTION_CREATE_ORDER(using USDC) -> (⌛️ GMX Callback) -> GMToken
    function testLeverageBorrow() public {
        uint256 usdcAmountOut = 5_000e6;
        uint256 gmEthTokenOut = 5400 ether;

        exchange.setTokens(ERC20(mim), ERC20(usdc));
        deal(usdc, address(exchange), usdcAmountOut);

        // Leveraging needs to be splitted into 2 transaction since
        // the order needs to be picked up by the gmx executor
        {
            pushPrank(alice);
            uint8 numActions = 5;
            uint8 i;
            uint8[] memory actions = new uint8[](numActions);
            uint256[] memory values = new uint256[](numActions);
            bytes[] memory datas = new bytes[](numActions);

            box.setMasterContractApproval(alice, masterContract, true, 0, 0, 0);
            gmETH.safeApprove(address(box), type(uint256).max);

            // Bento Deposit
            actions[i] = 20;
            datas[i++] = abi.encode(gmETH, alice, 10_000 ether, 0);

            // Add collateral
            actions[i] = 10;
            datas[i++] = abi.encode(-1, alice, false);

            // Borrow
            actions[i] = 5;
            datas[i++] = abi.encode(5_000 ether, address(exchange));

            // Swap MIM -> USDC
            actions[i] = 30;
            datas[i++] = abi.encode(
                address(exchange),
                abi.encodeWithSelector(ExchangeRouterMock.swapAndDepositToDegenBox.selector, address(box), address(orderAgent)),
                false,
                false,
                uint8(1)
            );

            // Create Order
            actions[i] = 101;
            values[i] = 1 ether;
            datas[i++] = abi.encode(usdc, true, usdcAmountOut, 1 ether, type(uint128).max, 0);

            gmETHDeployment.cauldron.cook{value: 1 ether}(actions, values, datas);
            popPrank();
        }

        // Some blocks laters, we receive the tokens...
        IGmRouterOrder order = ICauldronV4GmxV2(address(gmETHDeployment.cauldron)).orders(alice);
        pushPrank(GM_ETH_WHALE);
        gmETH.safeTransfer(address(order), gmEthTokenOut);

        pushPrank(router.depositHandler());
        _callAfterDepositExecution(IGmxV2DepositCallbackReceiver(address(order)));
        popPrank();

        popPrank();

        // deleverage
        {
            pushPrank(alice);

            uint256 userCollateralShare = gmETHDeployment.cauldron.userCollateralShare(alice);
            uint256 amount = box.toAmount(IERC20(gmETH), userCollateralShare, false);

            uint8 numActions = 2;
            uint8 i;
            uint8[] memory actions = new uint8[](numActions);
            uint256[] memory values = new uint256[](numActions);
            bytes[] memory datas = new bytes[](numActions);

            // Remove collateral to order agent
            actions[i] = 4;
            datas[i++] = abi.encode(userCollateralShare, address(orderAgent));

            // Create Withdraw Order for 100% of the collateral
            actions[i] = 101;
            values[i] = 1 ether;
            datas[i++] = abi.encode(IERC20(gmETH), false, amount, 1 ether, type(uint128).max, 0);

            gmETHDeployment.cauldron.cook{value: 1 ether}(actions, values, datas);

            popPrank();
        }

        // Some blocks laters, we receive the tokens...
        uint256 debt = 7500000000000000000;
        uint256 mimAmountOut = 5_000 ether + debt;
        uint256 usdcTokenOut = 5_000 ether;

        exchange.setTokens(ERC20(usdc), ERC20(mim));
        deal(mim, address(exchange), mimAmountOut);

        order = ICauldronV4GmxV2(address(gmETHDeployment.cauldron)).orders(alice);
        deal(usdc, address(order), usdcTokenOut);

        assertEq(weth.balanceOf(address(order)), 0);

        // send fake eth to simulate a refund
        pushPrank(alice);
        address(order).safeTransferETH(0.01 ether);
        popPrank();

        assertEq(weth.balanceOf(address(order)), 0.01 ether);

        // withdraw from order and swap to mim
        {
            pushPrank(alice);

            uint256 userCollateralShare = gmETHDeployment.cauldron.userCollateralShare(alice);
            uint256 borrowPart = gmETHDeployment.cauldron.userBorrowPart(alice);

            uint8 numActions = 4;
            uint8 i;
            uint8[] memory actions = new uint8[](numActions);
            uint256[] memory values = new uint256[](numActions);
            bytes[] memory datas = new bytes[](numActions);

            // withdraw WETH execution gas refund from the order and send to carol
            // don't close the order yet.
            actions[i] = 9;
            datas[i++] = abi.encode(weth, address(carol), 0.01 ether, false);

            // withdraw USDC from the order and send to swapper
            actions[i] = 9;
            datas[i++] = abi.encode(usdc, address(exchange), usdcTokenOut, true);

            // USDC -> MIM
            actions[i] = 30;
            datas[i++] = abi.encode(
                address(exchange),
                abi.encodeWithSelector(ExchangeRouterMock.swapFromDegenBoxAndDepositToDegenBox.selector, address(box), alice),
                false,
                false,
                uint8(1)
            );

            // Repay
            actions[i] = 2;
            datas[i++] = abi.encode(int256(borrowPart), alice, false);

            gmETHDeployment.cauldron.cook(actions, values, datas);

            borrowPart = gmETHDeployment.cauldron.userBorrowPart(alice);
            assertEq(borrowPart, 0);

            userCollateralShare = gmETHDeployment.cauldron.userCollateralShare(alice);
            assertEq(userCollateralShare, 0);

            popPrank();

            assertEq(weth.balanceOf(address(order)), 0 ether);
            assertEq(box.balanceOf(IERC20(weth), address(carol)), 0.01 ether);
        }

        uint256 cauldronMimBalance = box.balanceOf(IERC20(mim), address(gmETHDeployment.cauldron));
        assertEq(cauldronMimBalance, 1_000_000e18 + debt);
    }

    function testLiquidation(uint256 collateralAmount) public {
        collateralAmount = bound(collateralAmount, 1 ether, 10_000 ether);
        pushPrank(alice);
        CauldronTestLib.depositAndBorrow(box, gmETHDeployment.cauldron, masterContract, IERC20(gmETH), alice, 10_000 ether, 40);

        assertEq(gmETHDeployment.cauldron.userCollateralShare(alice), 10_000 ether);
        assertTrue(gmETHDeployment.cauldron.isSolvent(alice), "alice is insolvent");

        uint256 userCollateralShare = gmETHDeployment.cauldron.userCollateralShare(alice);
        uint256 amount = box.toAmount(IERC20(gmETH), userCollateralShare, false);

        // user is withdrawing 100% of his collateral.
        // verify that this gets cancels when calling liquidate later

        uint8 numActions = 2;
        uint8 i;
        uint8[] memory actions = new uint8[](numActions);
        uint256[] memory values = new uint256[](numActions);
        bytes[] memory datas = new bytes[](numActions);

        // Remove collateral to order agent
        actions[i] = 4;
        datas[i++] = abi.encode(userCollateralShare, address(orderAgent));

        // Create Withdraw Order for 100% of the collateral
        actions[i] = 101;
        values[i] = 1 ether;
        datas[i++] = abi.encode(IERC20(gmETH), false, amount, 1 ether, type(uint128).max, 0);

        gmETHDeployment.cauldron.cook{value: 1 ether}(actions, values, datas);

        // withdrawal order initiated but not executed, should be using `orderValueInCollateral` using minOut
        assertTrue(gmETHDeployment.cauldron.isSolvent(alice), "alice is insolvent");

        vm.mockCall(address(gmETHDeployment.oracle), abi.encodeWithSelector(ProxyOracle.get.selector), abi.encode(true, 1e19));
        gmETHDeployment.cauldron.updateExchangeRate();
        assertFalse(gmETHDeployment.cauldron.isSolvent(alice), "alice is still solvent");
        popPrank();

        assertEq(gmETHDeployment.cauldron.userCollateralShare(alice), 0); // all collaterals are in the order

        // At this point Alice is insolvent and the order is from GM -> USDC
        // No matter how much GM is gone into the GMX router or that we receive or not USDC
        // The pricing for the order is always based on the minOut of the order

        pushPrank(MIM_WHALE);
        box.setMasterContractApproval(MIM_WHALE, masterContract, true, 0, 0, 0);
        mim.safeTransfer(address(box), 100_000e18);
        box.deposit(IERC20(mim), address(box), MIM_WHALE, 100_000e18, 0);

        // minmum number of blocks to wait before we can cancel an order
        // source: gmx-synthetics ExchangeUtils.sol:validateRequestCancellation
        uint256 requestExpirationAge = 1200;
        advanceBlocks(requestExpirationAge);

        vm.expectEmit(true, true, true, false);
        emit LogAddCollateral(address(box), alice, 0);
        vm.expectEmit(true, false, false, false);
        emit LogOrderCanceled(alice, address(0));
        _liquidate(address(gmETHDeployment.cauldron), alice, 900 ether); // partial liquidation to keep things simple
        popPrank();
    }

    function testReceive() public {
        address weth = toolkit.getAddress(block.chainid, "weth");

        // create a dummy order
        address order = address(
            new GmxV2CauldronRouterOrder(
                box,
                router,
                toolkit.getAddress(block.chainid, "gmx.v2.syntheticsRouter"),
                IGmxReader(toolkit.getAddress(block.chainid, "gmx.v2.reader")),
                IWETH(weth)
            )
        );

        assertEq(weth.balanceOf(order), 0);
        address(order).safeTransferETH(0 ether);
        assertEq(weth.balanceOf(order), 0);

        pushPrank(alice);
        address(order).safeTransferETH(1 ether);
        popPrank();
        assertEq(weth.balanceOf(order), 1 ether);
    }

    function testMaxMinOuts() public {
        pushPrank(address(gmETHDeployment.cauldron));
        GmRouterOrderParams memory params = GmRouterOrderParams(address(0), false, 0, 0, type(uint128).max, 1);
        vm.expectRevert(abi.encodeWithSelector(ErrMinOutTooLarge.selector));
        orderAgent.createOrder(alice, params);
        popPrank();
    }

    function testSendValueInCollateral() public {
        pushPrank(GM_ETH_WHALE);
        gmETH.safeTransfer(address(box), 100_000 ether);
        box.deposit(IERC20(gmETH), address(box), address(orderAgent), 100_000 ether, 0);
        popPrank();

        // create a random working withdrawal order
        pushPrank(address(gmETHDeployment.cauldron));
        GmRouterOrderParams memory params = GmRouterOrderParams(address(gmETH), false, 100_000 ether, 0, type(uint128).max, 0);
        IGmRouterOrder order = IGmRouterOrder(orderAgent.createOrder(alice, params));
        deal(usdc, address(order), 200_000e6);

        (uint256 shortExchangeRate, uint256 marketExchangeRate) = order.getExchangeRates();
        assertEq(marketExchangeRate, 1089611872333813650);
        assertEq(shortExchangeRate, 99989923);
        assertEq(box.balanceOf(IERC20(usdc), address(bob)), 0);

        /// - amountMarketToken is 100_000e18
        /// - 1 gmETH = 0.9177579883175501 USD
        /// - 1 USDC = 0.99989923 USD
        /// 100_000 * 0.9177579883175501 / 0.99989923 = ≈91785.04 USDC
        order.sendValueInCollateral(bob, 100_000 ether);
        uint256 usdcAmount = box.balanceOf(IERC20(usdc), address(bob));
        assertEq(usdcAmount, 91785048011);

        popPrank();
    }

    function testDepositOrderValueInCollateral() public {
        /// - amountMarketToken is 100_000e18
        /// - 1 gmETH = 0.9177579883175501 USD (1.0896118723338137 inverted)
        /// - 1 USDC = 0.99989923 USD

        //////////// Deposit Orders ///////////////
        // Case where minOut is higher than the market value of gm input token
        {
            deal(usdc, address(box), 100_000e6);
            box.deposit(IERC20(usdc), address(box), address(orderAgent), 100_000e6, 0);

            pushPrank(address(gmETHDeployment.cauldron));
            GmRouterOrderParams memory params = GmRouterOrderParams(usdc, true, 100_000e6, 0, 110_000 ether, 0);
            IGmRouterOrder order = IGmRouterOrder(orderAgent.createOrder(alice, params));
            (uint256 shortExchangeRate, uint256 marketExchangeRate) = order.getExchangeRates();
            assertEq(marketExchangeRate, 1089611872333813650);
            assertEq(shortExchangeRate, 99989923);

            assertEq(order.orderValueInCollateral(), 108950207214543857159848);
            popPrank();
        }

        // Case where minOut is lower than the market value of gm input token
        {
            deal(usdc, address(box), 100_000e6);
            box.deposit(IERC20(usdc), address(box), address(orderAgent), 100_000e6, 0);

            pushPrank(address(gmETHDeployment.cauldron));
            GmRouterOrderParams memory params = GmRouterOrderParams(usdc, true, 100_000e6, 0, 12_324 ether, 0);
            IGmRouterOrder order = IGmRouterOrder(orderAgent.createOrder(alice, params));
            (uint256 shortExchangeRate, uint256 marketExchangeRate) = order.getExchangeRates();
            assertEq(marketExchangeRate, 1089611872333813650);
            assertEq(shortExchangeRate, 99989923);

            assertEq(order.orderValueInCollateral(), 12_324 ether);
            popPrank();
        }
    }

    function testWithdrawalOrderValueInCollateral() public {
        /// - amountMarketToken is 100_000e18
        /// - 1 gmETH = 0.9177579883175501 USD (1.0896118723338137 inverted)
        /// - 1 USDC = 0.99989923 USD
        //////////// Withdrawal Orders ////////////
        // Case where minOut+minOutLong exceeed the market value of gm input token
        {
            pushPrank(GM_ETH_WHALE);
            gmETH.safeTransfer(address(box), 100_000 ether);
            box.deposit(IERC20(gmETH), address(box), address(orderAgent), 100_000 ether, 0);
            popPrank();

            pushPrank(address(gmETHDeployment.cauldron));
            GmRouterOrderParams memory params = GmRouterOrderParams(address(gmETH), false, 100_000 ether, 0, 25_000e6, 75_000e6);
            IGmRouterOrder order = IGmRouterOrder(orderAgent.createOrder(alice, params));
            (uint256 shortExchangeRate, uint256 marketExchangeRate) = order.getExchangeRates();
            assertEq(marketExchangeRate, 1089611872333813650);
            assertEq(shortExchangeRate, 99989923);

            /// since the real value is 91,785 USDC and 100_000e6 worth of USDC was provided,
            // it's going to be floored to 100,000 gmETH
            assertEq(order.orderValueInCollateral(), 100_000 ether);
            popPrank();
        }

        // Case where minOut+minOutLong doesn't exceed
        {
            pushPrank(GM_ETH_WHALE);
            gmETH.safeTransfer(address(box), 100_000 ether);
            box.deposit(IERC20(gmETH), address(box), address(orderAgent), 100_000 ether, 0);
            popPrank();

            pushPrank(address(gmETHDeployment.cauldron));
            GmRouterOrderParams memory params = GmRouterOrderParams(address(gmETH), false, 100_000 ether, 0, 91_000e6, 785e6);
            IGmRouterOrder order = IGmRouterOrder(orderAgent.createOrder(alice, params));
            (uint256 shortExchangeRate, uint256 marketExchangeRate) = order.getExchangeRates();
            assertEq(marketExchangeRate, 1089611872333813650);
            assertEq(shortExchangeRate, 99989923);

            // 91785 * 0.99989923 * 1.0896118723338137
            assertEq(order.orderValueInCollateral(), 99999947691869079294167);
            popPrank();
        }
    }

    function testFuzzDepositWithdrawalOrders(uint128 amount, uint128 minOut1, uint128 minOut2, bool deposit) public {
        uint8[] memory actions = new uint8[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory datas = new bytes[](1);
        actions[0] = 101;
        values[0] = 1 ether;

        pushPrank(alice);
        box.setMasterContractApproval(alice, masterContract, true, 0, 0, 0);

        if (deposit) {
            console2.log("[DEPOSIT]");
            amount = uint128(bound(amount, 1e6, 100_000_000_000e6));
            console2.log("usdc amount %s", amount / 1e6);
            deal(usdc, address(box), amount);

            console2.log("usdc amount %s", amount);
            box.deposit(IERC20(usdc), address(box), address(orderAgent), amount, 0);

            // Create Deposit Order
            datas[0] = abi.encode(usdc, true, amount, 1 ether, minOut1, 0);
            gmETHDeployment.cauldron.cook{value: 1 ether}(actions, values, datas);
        } else {
            console2.log("[WITHDRAWAL]");
            amount = uint128(bound(amount, 1 ether, gmETH.balanceOf(GM_ETH_WHALE)));
            console2.log("market amount %s", amount / 1e18);
            console2.log("minOut1", minOut1);
            console2.log("minOut2", minOut2);

            pushPrank(GM_ETH_WHALE);
            gmETH.safeTransfer(address(box), amount);
            box.deposit(IERC20(gmETH), address(box), address(orderAgent), amount, 0);
            popPrank();

            // Create Withdrawal Order
            if (uint256(minOut1) + uint256(minOut2) > type(uint128).max) {
                vm.expectRevert(abi.encodeWithSignature("ErrMinOutTooLarge()"));
            }
            datas[0] = abi.encode(gmETH, false, amount, 1 ether, minOut1, minOut2);
            gmETHDeployment.cauldron.cook{value: 1 ether}(actions, values, datas);
        }
        popPrank();
    }

    function _liquidate(address cauldron, address account, uint256 borrowPart) internal {
        address[] memory users = new address[](1);
        users[0] = account;
        uint256[] memory maxBorrowParts = new uint256[](1);
        maxBorrowParts[0] = borrowPart;

        ICauldronV4(cauldron).liquidate(users, maxBorrowParts, address(this), address(0), new bytes(0));
    }

    // IGmxV2DepositCallbackReceiver.afterDepositExecution
    function _callAfterDepositExecution(IGmxV2DepositCallbackReceiver target) public {
        bytes32 key = bytes32(0);

        // Prepare the call data
        address[] memory longTokenSwapPath = new address[](0);
        address[] memory shortTokenSwapPath = new address[](0);

        IGmxV2Deposit.Addresses memory addresses = IGmxV2Deposit.Addresses(
            address(target),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            longTokenSwapPath,
            shortTokenSwapPath
        );

        IGmxV2Deposit.Numbers memory numbers = IGmxV2Deposit.Numbers(0, 0, 0, 0, 0, 0);
        IGmxV2Deposit.Flags memory flags = IGmxV2Deposit.Flags(false);
        IGmxV2Deposit.Props memory deposit = IGmxV2Deposit.Props(addresses, numbers, flags);

        bytes memory data = "";
        for (uint i = 0; i < 7; i++) {
            data = abi.encodePacked(data, hex"0000000000000000000000000000000000000000000000000000000000000000");
        }

        IGmxV2EventUtils.EventLogData memory eventData = abi.decode(data, (IGmxV2EventUtils.EventLogData));
        target.afterDepositExecution(key, deposit, eventData);
    }
}
