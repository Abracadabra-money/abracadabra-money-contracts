// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@BoringSolidity/ERC20.sol";
import "utils/BaseTest.sol";
import "script/GmxV2.s.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import "./utils/CauldronTestLib.sol";
import "./mocks/ExchangeRouterMock.sol";
import {ICauldronV4GmxV2} from "/interfaces/ICauldronV4GmxV2.sol";
import {IGmRouterOrder, GmRouterOrderParams} from "/periphery/GmxV2CauldronOrderAgent.sol";
import {IGmxV2DepositCallbackReceiver, IGmxV2Deposit, IGmxV2EventUtils} from "/interfaces/IGmxV2.sol";
import {LiquidationHelper} from "/periphery/LiquidationHelper.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IWETH} from "/interfaces/IWETH.sol";
import {Owned} from "@solmate/auth/Owned.sol";
import {GmTestLib} from "./utils/GmTestLib.sol";

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
    GmxV2Script.MarketDeployment gmETHSingleSidedDeployment;
    GmxV2Script.MarketDeployment gmBTCSingleSidedDeployment;

    event LogOrderCanceled(address indexed user, address indexed order);
    event LogAddCollateral(address indexed from, address indexed to, uint256 share);
    error ErrMinOutTooLarge();

    address constant GM_BTC_WHALE = 0x8d77fa0058335CE7dA21F421fA5154feeB0aBFdE;
    address constant GM_BTC_SingleSided_WHALE = 0x69cE8721790Edbdcd2b4155D853d99d2680477B0;
    address constant GM_ETH_WHALE = 0x56CC5A9c0788e674f17F7555dC8D3e2F1C0313C0;
    address constant GM_ARB_WHALE = 0x4e4c132Ba29E6927b39d0b2286D6BE8c1cf3647D;
    address constant GM_SOL_WHALE = 0x7C8FeF8eA9b1fE46A7689bfb8149341C90431D38;
    address constant GM_LINK_WHALE = 0xd040065A450E0A4a6e310C088f61e2bc9156Be55;

    address constant MIM_WHALE = 0x27807dD7ADF218e1f4d885d54eD51C70eFb9dE50;
    address constant GMX_EXECUTOR = 0xf1e1B2F4796d984CCb8485d43db0c64B83C1FA6d;

    address gmBTCSingleSided;
    address mim;
    address weth;
    address wbtc;
    address masterContract;
    IBentoBoxV1 box;
    ExchangeRouterMock exchange;
    IGmxV2ExchangeRouter router;

    function setUp() public override {
        fork(ChainId.Arbitrum, 278906004);
        super.setUp();

        GmxV2Script script = new GmxV2Script();
        script.setTesting(true);

        {
            (masterContract, orderAgent, , gmETHSingleSidedDeployment, , gmBTCSingleSidedDeployment, , , ) = script
            .deploy();
        }
        
        box = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        mim = toolkit.getAddress(block.chainid, "mim");
        gmBTCSingleSided = toolkit.getAddress(block.chainid, "gmx.v2.gmBTCSingleSided");
        
        weth = toolkit.getAddress(block.chainid, "weth");
        wbtc = toolkit.getAddress(block.chainid, "wbtc");
        router = IGmxV2ExchangeRouter(toolkit.getAddress(block.chainid, "gmx.v2.exchangeRouter"));
        exchange = new ExchangeRouterMock(address(0), address(0));
        
        
        {
        // Alice just made it
        deal(wbtc, alice, 100_000e6);
        pushPrank(GM_BTC_SingleSided_WHALE);
        gmBTCSingleSided.safeTransfer(alice, 100_000 ether);
        popPrank();
        }
        
        // put 1m mim inside the cauldrons
        pushPrank(MIM_WHALE);
        mim.safeTransfer(address(box), 2_000_000e18);
        popPrank();

        box.deposit(IERC20(mim), address(box), address(gmETHSingleSidedDeployment.cauldron), 1_000_000e18, 0);
        box.deposit(IERC20(mim), address(box), address(gmBTCSingleSidedDeployment.cauldron), 1_000_000e18, 0);

        pushPrank(box.owner());
        box.whitelistMasterContract(masterContract, true);
        popPrank();
    }

    function testOracles() public view {
        uint256 price;

        console2.log("=== gmETHSingleSided SingleSided OraclePrice ===");
        (, price) = gmETHSingleSidedDeployment.oracle.peek(bytes(""));
        console2.log("price", price);
        assertEq(price, 968292910239471974);

        console2.log("=== gmBTC SingleSided OraclePrice ===");
        (, price) = gmBTCSingleSidedDeployment.oracle.peek(bytes(""));
        console2.log("price", price);
        assertEq(price, 707036309880736019);
    }


    function testLeverageBorrowSingleSided() public {
        uint256 wbtcAmountOut = 5000000;
        uint256 gmEthTokenOut = 5400 ether;

        exchange.setTokens(ERC20(mim), ERC20(wbtc));
        deal(wbtc, address(exchange), wbtcAmountOut);

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
            gmBTCSingleSided.safeApprove(address(box), type(uint256).max);

            // Bento Deposit
            actions[i] = 20;
            datas[i++] = abi.encode(gmBTCSingleSided, alice, 0, 9836523609103193148261);

            // Add collateral
            actions[i] = 10;
            datas[i++] = abi.encode(-2, alice, false);

            // Borrow
            actions[i] = 5;
            datas[i++] = abi.encode(5_000 ether, address(exchange));

            // Swap MIM -> WBTC
            actions[i] = 30;
            datas[i++] = abi.encode(
                address(exchange),
                abi.encodeWithSelector(ExchangeRouterMock.swapAndDepositToDegenBox.selector, address(box), address(orderAgent)),
                false,
                false,
                uint8(1)
            );

            // Create Order
            actions[i] = 3;
            values[i] = 1 ether;
            datas[i++] = abi.encode(wbtc, true, wbtcAmountOut, 1 ether, type(uint128).max, 0);

            gmBTCSingleSidedDeployment.cauldron.cook{value: 1 ether}(actions, values, datas);
            popPrank();
        }

        // Some blocks laters, we receive the tokens...
        IGmRouterOrder order = ICauldronV4GmxV2(address(gmBTCSingleSidedDeployment.cauldron)).orders(alice);
        pushPrank(GM_BTC_SingleSided_WHALE);
        gmBTCSingleSided.safeTransfer(address(order), gmEthTokenOut);

        pushPrank(router.depositHandler());
        GmTestLib.callAfterDepositExecution(IGmxV2DepositCallbackReceiver(address(order)));
        popPrank();

        popPrank();

        

        // deleverage
        {
            pushPrank(alice);

            uint256 userCollateralShare = gmBTCSingleSidedDeployment.cauldron.userCollateralShare(alice);
            uint256 amount = box.toAmount(IERC20(gmBTCSingleSided), userCollateralShare, false);

            uint8 numActions = 2;
            uint8 i;
            uint8[] memory actions = new uint8[](numActions);
            uint256[] memory values = new uint256[](numActions);
            bytes[] memory datas = new bytes[](numActions);

            // Remove collateral to order agent
            actions[i] = 4;
            datas[i++] = abi.encode(userCollateralShare, address(orderAgent));

            // Create Withdraw Order for 100% of the collateral
            actions[i] = 3;
            values[i] = 1 ether;
            datas[i++] = abi.encode(IERC20(gmBTCSingleSided), false, amount, 1 ether, type(uint128).max, 0);

            gmBTCSingleSidedDeployment.cauldron.cook{value: 1 ether}(actions, values, datas);

            popPrank();
        }

        // Some blocks laters, we receive the tokens...
        uint256 debt = 25000000000000000000;
        uint256 mimAmountOut = 5_000 ether + debt;
        uint256 usdcTokenOut = 5_000 ether;

        exchange.setTokens(ERC20(wbtc), ERC20(mim));
        deal(mim, address(exchange), mimAmountOut);

        order = ICauldronV4GmxV2(address(gmBTCSingleSidedDeployment.cauldron)).orders(alice);
        deal(wbtc, address(order), usdcTokenOut);

        assertEq(weth.balanceOf(address(order)), 0);

        // send fake eth to simulate a refund
        pushPrank(alice);
        address(order).safeTransferETH(0.01 ether);
        popPrank();

        assertEq(weth.balanceOf(address(order)), 0);

        // withdraw from order and swap to mim
        {
            pushPrank(alice);

            uint256 userCollateralShare = gmBTCSingleSidedDeployment.cauldron.userCollateralShare(alice);
            uint256 borrowPart = gmBTCSingleSidedDeployment.cauldron.userBorrowPart(alice);

            uint8 numActions = 3;
            uint8 i;
            uint8[] memory actions = new uint8[](numActions);
            uint256[] memory values = new uint256[](numActions);
            bytes[] memory datas = new bytes[](numActions);

            // withdraw USDC from the order and send to swapper
            actions[i] = 9;
            datas[i++] = abi.encode(wbtc, address(exchange), usdcTokenOut, true);

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

            gmBTCSingleSidedDeployment.cauldron.cook(actions, values, datas);

            borrowPart = gmBTCSingleSidedDeployment.cauldron.userBorrowPart(alice);
            assertEq(borrowPart, 0);

            userCollateralShare = gmBTCSingleSidedDeployment.cauldron.userCollateralShare(alice);
            assertEq(userCollateralShare, 0);

            popPrank();

            assertEq(weth.balanceOf(address(order)), 0 ether);
            assertEq(box.balanceOf(IERC20(weth), address(carol)), 0 ether);
        }
    

        uint256 cauldronMimBalance = box.balanceOf(IERC20(mim), address(gmBTCSingleSidedDeployment.cauldron));
        assertEq(cauldronMimBalance, 1_000_000e18 + debt);
    }

}
