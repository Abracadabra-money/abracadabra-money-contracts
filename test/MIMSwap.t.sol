// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MIMSwap.s.sol";
import {LibClone} from "@solady/utils/LibClone.sol";
import {MagicLP} from "/mimswap/MagicLP.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {IFeeRateModel} from "/mimswap/interfaces/IFeeRateModel.sol";
import {WETH} from "@solady/tokens/WETH.sol";
import {IWETH} from "/interfaces/IWETH.sol";
import {IMagicLP} from "/mimswap/interfaces/IMagicLP.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IFactory} from "/mimswap/interfaces/IFactory.sol";
import {MockWETH} from "./fuzzing/mocks/MockWETH.sol";
import {Math} from "/mimswap/libraries/Math.sol";
import {AddLiquidityImbalancedParams, AddLiquidityOneSideParams} from "/mimswap/periphery/Router.sol";

function newMagicLP() returns (MagicLP) {
    return new MagicLP(address(tx.origin));
}

uint256 constant MIN_LP_FEE_RATE = 1e14;
address constant BURN_ADDRESS = address(0xdead);

contract MIMSwapTestBase is BaseTest {
    MagicLP implementation;
    FeeRateModel feeRateModel;
    Factory factory;
    Router router;

    function initialize(uint256 chainId, uint256 blockNumber) public returns (MIMSwapScript script) {
        fork(chainId, blockNumber);
        super.setUp();

        script = new MIMSwapScript();
        script.setTesting(true);
    }

    function afterDeployed() public {}
}

contract MIMSwapTest is MIMSwapTestBase {
    using SafeTransferLib for address;

    address mim;
    address dai;

    function setUp() public override {
        MIMSwapScript script = super.initialize(ChainId.Arbitrum, 216607071);
        (implementation, feeRateModel, factory, router) = script.deploy();

        mim = toolkit.getAddress(block.chainid, "mim");
        dai = toolkit.getAddress(block.chainid, "dai");

        super.afterDeployed();
    }

    // forge-config: default.fuzz.runs = 50000
    function testSqrt(uint256 a, uint256 b) public pure {
        vm.assume(a != b);
        vm.assume(a != 0);
        vm.assume(b != 0);
        vm.assume(a >= 100);
        vm.assume(b >= 100);
        vm.assume((a > b && a - b > 100) || (b > a && b - a > 100));

        uint a2 = Math.sqrt(a);
        uint b2 = Math.sqrt(b);

        console2.log("a", a);
        console2.log("b", b);

        if (a < b) {
            assertLe(a2, b2, "sqrt(x) < sqrt(y) if x < y");
        }
    }

    // forge-config: default.fuzz.runs = 50000
    function testSqrt2(uint256 x) public pure {
        console2.log(x);
        uint y = Math.sqrt(x);
        assertLe(y * y, x);
    }

    function testFuzzFeeModel(uint256 lpFeeRate) public view {
        lpFeeRate = bound(lpFeeRate, implementation.MIN_LP_FEE_RATE(), implementation.MAX_LP_FEE_RATE());
        (uint256 adjustedLpFeeRate, uint256 mtFeeRate) = feeRateModel.getFeeRate(address(0), lpFeeRate);

        assertEq(adjustedLpFeeRate + mtFeeRate, lpFeeRate);
    }

    function testRescueFunds() public {
        MagicLP lp = _createDefaultLp(false);

        // non-pol pool should not be able to rescue
        pushPrank(lp.implementation().owner());
        vm.expectRevert(abi.encodeWithSignature("ErrNotAllowed()"));
        lp.rescue(mim, alice, 1 ether);
        popPrank();

        lp = _createDefaultLp(true);
        ERC20Mock token = new ERC20Mock("foo", "bar");
        deal(address(token), address(lp), 1 ether);

        pushPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("ErrNotAllowedImplementationOperator()"));
        lp.rescue(mim, alice, 1 ether);
        vm.expectRevert(abi.encodeWithSignature("ErrNotAllowedImplementationOperator()"));
        lp.rescue(address(token), alice, 1 ether);
        popPrank();

        pushPrank(lp.implementation().owner());
        vm.expectRevert(abi.encodeWithSignature("ErrNotAllowed()"));
        lp.rescue(mim, alice, 1 ether);
        vm.expectRevert(abi.encodeWithSignature("ErrNotAllowed()"));
        lp.rescue(dai, alice, 1 ether);

        uint balanceBefore = token.balanceOf(alice);
        uint balanceBeforeLP = token.balanceOf(address(lp));

        lp.rescue(address(token), alice, 1 ether);
        assertEq(token.balanceOf(alice), balanceBefore + 1 ether);
        assertEq(token.balanceOf(address(lp)), balanceBeforeLP - 1 ether);

        vm.expectRevert();
        lp.rescue(address(token), alice, 1 ether);
        popPrank();
    }

    function testOnlyCallableOnImplementation() public {
        MagicLP lp = _createDefaultLp(false);
        MagicLP _implementation = MagicLP(address(lp.implementation()));

        vm.expectRevert(abi.encodeWithSignature("ErrNotImplementation()"));
        lp.setOperator(bob, true);

        vm.expectRevert(abi.encodeWithSignature("ErrNotImplementationOwner()"));
        _implementation.setOperator(bob, true);
    }

    function testCreatePoolAndAddLiquidityETH() public {
        pushPrank(alice);
        deal(address(mim), address(alice), 8000 ether);
        mim.safeApprove(address(router), 8000 ether);
        (address lp, ) = router.createPoolETH{value: 1 ether}(mim, true, MIN_LP_FEE_RATE, 1 ether, 0, alice, 4000 ether, false);
        router.addLiquidityETH{value: 1 ether}(lp, alice, alice, 4000 ether, 0, block.timestamp);
        popPrank();
    }

    function _createDefaultLp(bool pol) internal returns (MagicLP lp) {
        lp = MagicLP(factory.create(mim, dai, MIN_LP_FEE_RATE, 997724689700000000, 100000000000000, pol));

        assertNotEq(address(lp.implementation()), address(0));
        assertEq(lp.owner(), address(0));
        assertNotEq(lp.implementation().owner(), address(0));
    }
}

contract FactoryTest is BaseTest {
    ERC20Mock baseToken;
    ERC20Mock quoteToken;

    MagicLP lp;

    FeeRateModel maintainerFeeRateModel;
    address registryOwner;

    address authorizedCreator;

    address factoryOwner;
    address maintainer;
    Factory factory;

    function setUp() public override {
        vm.chainId(ChainId.Arbitrum);
        super.setUp();

        maintainer = makeAddr("Maintainer");
        factoryOwner = makeAddr("FactoryOwner");
        authorizedCreator = makeAddr("AuthorizedCreator");

        baseToken = new ERC20Mock("BaseToken", "BaseToken");
        quoteToken = new ERC20Mock("QuoteToken", "QuoteToken");

        lp = newMagicLP();
        maintainerFeeRateModel = new FeeRateModel(maintainer, address(0));
        factory = new Factory(address(lp), IFeeRateModel(address(maintainerFeeRateModel)), factoryOwner);
    }

    function testCreate() public {
        vm.prank(authorizedCreator);
        MagicLP clone = MagicLP(
            factory.create(address(baseToken), address(quoteToken), MIN_LP_FEE_RATE, 1_000_000, 500000000000000, false)
        );

        assertEq(clone.balanceOf(alice), 0);
        baseToken.mint(address(clone), 1000 ether);
        quoteToken.mint(address(clone), 1000 ether);
        clone.buyShares(alice);
        assertNotEq(clone.balanceOf(alice), 0);
    }

    function testAddRemovePoolByAdmin() public {
        address pool = makeAddr("random pool");
        address pool2 = makeAddr("random pool2");

        pushPrank(alice);
        vm.expectRevert();
        factory.addPool(alice, address(baseToken), address(quoteToken), pool);
        popPrank();

        pushPrank(factoryOwner);
        factory.addPool(alice, address(baseToken), address(quoteToken), pool);
        assertEq(factory.pools(address(baseToken), address(quoteToken), 0), pool);
        assertEq(factory.getPoolCount(address(baseToken), address(quoteToken)), 1);
        assertEq(factory.getUserPoolCount(factoryOwner), 0);

        vm.expectRevert();
        assertEq(factory.userPools(factoryOwner, 0), address(0));

        assertEq(factory.userPools(alice, 0), pool);
        assertEq(factory.getUserPoolCount(alice), 1);
        popPrank();

        pushPrank(alice);
        vm.expectRevert();
        factory.removePool(alice, address(baseToken), address(quoteToken), 0, 0);
        popPrank();

        pushPrank(factoryOwner);
        vm.expectRevert();
        factory.removePool(alice, address(baseToken), address(quoteToken), 0, 1);
        factory.addPool(alice, address(baseToken), address(quoteToken), pool2);
        vm.expectRevert(abi.encodeWithSignature("ErrInvalidUserPoolIndex()"));
        factory.removePool(alice, address(baseToken), address(quoteToken), 0, 1);

        assertEq(factory.pools(address(baseToken), address(quoteToken), 0), pool);
        assertEq(factory.pools(address(baseToken), address(quoteToken), 1), pool2);
        assertEq(factory.userPools(alice, 0), pool);
        assertEq(factory.userPools(alice, 1), pool2);

        assertEq(factory.getPoolCount(address(baseToken), address(quoteToken)), 2);
        assertEq(factory.getUserPoolCount(alice), 2);
        factory.removePool(alice, address(baseToken), address(quoteToken), 0, 0);

        assertEq(factory.pools(address(baseToken), address(quoteToken), 0), pool2);
        assertEq(factory.userPools(alice, 0), pool2);

        assertEq(factory.getPoolCount(address(baseToken), address(quoteToken)), 1);
        assertEq(factory.getUserPoolCount(alice), 1);
        factory.removePool(alice, address(baseToken), address(quoteToken), 0, 0);

        assertEq(factory.getPoolCount(address(baseToken), address(quoteToken)), 0);
        assertEq(factory.getUserPoolCount(alice), 0);
        popPrank();
    }
}

contract RouterTest is BaseTest {
    ERC20Mock mim;
    WETH weth;

    FeeRateModel feeRateModel;
    MagicLP lp1;
    MagicLP lp2;
    Router router;

    address feeTo;
    address routerOwner;
    MagicLP impl;

    function setUp() public override {
        vm.chainId(ChainId.Arbitrum);
        super.setUp();

        mim = new ERC20Mock("MIM", "MIM");
        weth = new WETH();
        feeRateModel = new FeeRateModel(makeAddr("Maintainer"), address(0));
        impl = newMagicLP();
        lp1 = MagicLP(LibClone.clone(address(impl)));
        lp2 = MagicLP(LibClone.clone(address(impl)));

        lp1.init(address(mim), address(weth), MIN_LP_FEE_RATE, address(feeRateModel), 1 ether, 500000000000000, false);
        lp2.init(address(mim), address(weth), MIN_LP_FEE_RATE, address(feeRateModel), 1 ether, 500000000000000, false);

        mim.mint(address(lp1), 100000 ether);
        deal(address(weth), address(lp1), 100000 ether);
        lp1.buyShares(msg.sender);

        mim.mint(address(lp2), 100000 ether);
        deal(address(weth), address(lp2), 100000 ether);
        lp2.buyShares(msg.sender);

        feeTo = makeAddr("feeTo");
        routerOwner = makeAddr("routerOwner");

        address maintainer = makeAddr("Maintainer");
        address factoryOwner = makeAddr("FactoryOwner");
        FeeRateModel maintainerFeeRateModel = new FeeRateModel(maintainer, address(0));
        Factory factory = new Factory(address(impl), IFeeRateModel(address(maintainerFeeRateModel)), factoryOwner);

        router = new Router(IWETH(address(weth)), IFactory(address(factory)));

        _addPool(router.factory(), lp1);
        _addPool(router.factory(), lp2);
    }

    function testSellBaseTokensForTokens() public {
        mim.mint(alice, 1 ether);
        vm.prank(alice);
        mim.approve(address(router), 1 ether);
        vm.prank(alice);
        uint256 amountOut = router.sellBaseTokensForTokens(address(lp1), alice, 1 ether, 0, type(uint256).max);
        assertEq(weth.balanceOf(alice), amountOut);
        assertApproxEqRel(amountOut, 1 ether, 0.00011 ether);
    }

    function testRouter() public {
        mim.mint(alice, 1 ether);
        vm.prank(alice);
        mim.approve(address(router), 1 ether);
        address[] memory path = new address[](5);
        path[0] = address(lp1);
        path[1] = address(lp2);
        path[2] = address(lp1);
        path[3] = address(lp2);
        path[4] = address(lp1);
        uint256 directions = 10;

        vm.prank(alice);
        router.swapTokensForTokens(alice, 1 ether, path, directions, 1, type(uint256).max);
    }

    function testAddLiquidity() public {
        MagicLP lp = MagicLP(LibClone.clone(address(impl)));
        lp.init(address(mim), address(weth), MIN_LP_FEE_RATE, address(feeRateModel), 1 ether, 500000000000000, false);
        _addPool(router.factory(), lp);
        mim.mint(address(alice), 100000 ether);
        deal(address(weth), address(alice), 100000 ether);
        vm.startPrank(alice);
        mim.approve(address(router), 100000 ether);
        weth.approve(address(router), 100000 ether);
        router.addLiquidity(address(lp), alice, 500 ether, 10000 ether, 0, type(uint256).max);
        router.addLiquidity(address(lp), alice, 10000 ether, 500 ether, 0, type(uint256).max);
        vm.stopPrank();
        uint256 burnedShares = 1001;
        assertEq(lp.balanceOf(alice), 2 * 500 ether - burnedShares);
    }

    function _addPool(IFactory _factory, MagicLP _lp) private {
        pushPrank(Owned(address(_factory)).owner());
        IFactory(_factory).addPool(alice, _lp._BASE_TOKEN_(), _lp._QUOTE_TOKEN_(), address(_lp));
        popPrank();
    }

    function testDecimals() public {
        ERC20Mock base = new ERC20Mock("base", "base");
        base.setDecimals(0);

        ERC20Mock quote = new ERC20Mock("quote", "quote");
        quote.setDecimals(18);

        // ErrZeroDecimals
        vm.expectRevert(abi.encodeWithSignature("ErrZeroDecimals()"));
        router.createPool(address(base), address(quote), 0, 0, 0, address(0), 0, 0, false);
        vm.expectRevert(abi.encodeWithSignature("ErrZeroDecimals()"));
        router.createPoolETH(address(base), true, 0, 0, 0, address(0), 0, false);
        vm.expectRevert(abi.encodeWithSignature("ErrZeroDecimals()"));
        router.createPoolETH(address(base), false, 0, 0, 0, address(0), 0, false);

        // ErrTooLargeDecimals
        base.setDecimals(19);
        quote.setDecimals(18);
        vm.expectRevert(abi.encodeWithSignature("ErrTooLargeDecimals()"));
        router.createPool(address(base), address(quote), 0, 0, 0, address(0), 0, 0, false);
        base.setDecimals(18);
        quote.setDecimals(19);
        vm.expectRevert(abi.encodeWithSignature("ErrTooLargeDecimals()"));
        router.createPool(address(base), address(quote), 0, 0, 0, address(0), 0, 0, false);

        // ErrDecimalsDifferenceTooLarge
        base.setDecimals(5);
        quote.setDecimals(18);
        vm.expectRevert(abi.encodeWithSignature("ErrDecimalsDifferenceTooLarge()"));
        router.createPool(address(base), address(quote), 0, 0, 0, address(0), 0, 0, false);

        base.setDecimals(18);
        quote.setDecimals(18);
        // means it went past the decimal checks
        vm.expectRevert(abi.encodeWithSignature("ErrInvalidI()"));
        router.createPool(address(base), address(quote), 0, 0, 0, address(0), 0, 0, false);
    }
}

contract MagicLPTest is BaseTest {
    using SafeTransferLib for address;

    ERC20Mock mim;
    ERC20Mock dai;

    FeeRateModel feeRateModel;
    MagicLP lp;

    function setUp() public override {
        vm.chainId(ChainId.Arbitrum);
        super.setUp();

        mim = new ERC20Mock("MIM", "MIM");
        dai = new ERC20Mock("dai", "dai");
        feeRateModel = new FeeRateModel(makeAddr("Maintainer"), address(0));
        MagicLP lpImpl = newMagicLP();
        lp = MagicLP(LibClone.clone(address(lpImpl)));

        lp.init(address(mim), address(dai), MIN_LP_FEE_RATE, address(feeRateModel), 1_000_000, 500000000000000, true);
    }

    function testAddLiquiditySwap() public {
        assertEq(lp.balanceOf(alice), 0);
        mim.mint(address(lp), 1000 ether);
        dai.mint(address(lp), 1000 ether);
        lp.buyShares(alice);
        assertNotEq(lp.balanceOf(alice), 0);

        assertEq(dai.balanceOf(bob), 0);
        mim.mint(address(lp), 50 ether);
        lp.sellBase(bob);
        assertApproxEqRel(dai.balanceOf(bob), 50e6, 0.1 ether);

        assertEq(mim.balanceOf(bob), 0);
        uint256 balance = dai.balanceOf(bob);
        vm.prank(bob);
        dai.transfer(address(lp), balance);
        lp.sellQuote(bob);
        assertApproxEqRel(mim.balanceOf(bob), 50 ether, 0.00012 ether * 2); // around 0.01% fee for the first and second swap

        assertEq(lp.name(), "MagicLP MIM/dai");
    }

    function testFuzzReservesNonZero(uint256 addAmount, uint256 swapAmount, bool direction) public {
        addAmount = bound(addAmount, 2022, type(uint112).max);
        swapAmount = bound(swapAmount, 1, type(uint256).max - addAmount);

        MagicLP lpImpl = newMagicLP();
        lp = MagicLP(LibClone.clone(address(lpImpl)));

        lp.init(address(mim), address(dai), MIN_LP_FEE_RATE, address(feeRateModel), 1 ether, 500000000000000, true);
        assertEq(lp.balanceOf(alice), 0);
        mim.mint(address(lp), addAmount);
        dai.mint(address(lp), addAmount);
        lp.buyShares(alice);

        if (direction) {
            mim.mint(address(lp), swapAmount);
            try lp.sellBase(bob) {} catch {}
        } else {
            dai.mint(address(lp), swapAmount);
            try lp.sellQuote(bob) {} catch {}
        }

        (uint256 baseReserve, uint256 quoteReserve) = lp.getReserves();
        assertNotEq(baseReserve, 0);
        assertNotEq(quoteReserve, 0);
    }

    function testPausable() public {
        pushPrank(lp.implementation().owner());
        lp.setPaused(true);
        popPrank();

        bytes memory revertMsg = abi.encodeWithSignature("ErrNotAllowedImplementationOperator()");
        vm.expectRevert(revertMsg);
        lp.sellBase(bob);
        vm.expectRevert(revertMsg);
        lp.sellQuote(bob);
        vm.expectRevert(revertMsg);
        lp.flashLoan(0, 0, bob, "");
        vm.expectRevert(revertMsg);
        lp.buyShares(bob);
        vm.expectRevert(revertMsg);
        lp.sellShares(0, bob, 0, 0, "", 0);

        pushPrank(lp.implementation().owner());
        // pol owner should be able to do anything
        // testing normal path, assuming the `whenProtocolOwnedPoolOwnerAndNotPaused` worked
        vm.expectRevert(abi.encodeWithSignature("ErrIsZero()"));
        lp.sellBase(bob);
        vm.expectRevert(abi.encodeWithSignature("ErrIsZero()"));
        lp.sellQuote(bob);
        vm.expectRevert(abi.encodeWithSignature("ErrNoBaseInput()"));
        lp.buyShares(bob);
        vm.expectRevert(abi.encodeWithSignature("ErrExpired()"));
        lp.sellShares(0, bob, 0, 0, "", 0);
        lp.flashLoan(0, 0, bob, "");
        lp.setPaused(false);
        popPrank();

        // Normal path
        vm.expectRevert(abi.encodeWithSignature("ErrIsZero()"));
        lp.sellBase(bob);
        vm.expectRevert(abi.encodeWithSignature("ErrIsZero()"));
        lp.sellQuote(bob);
        vm.expectRevert(abi.encodeWithSignature("ErrNoBaseInput()"));
        lp.buyShares(bob);
        vm.expectRevert(abi.encodeWithSignature("ErrExpired()"));
        lp.sellShares(0, bob, 0, 0, "", 0);
        lp.flashLoan(0, 0, bob, "");
    }

    function testSetParameters() public {
        vm.expectRevert(abi.encodeWithSignature("ErrNotPaused()"));
        lp.setParameters(address(0), 0, 0, 0, 0, 0, 0, 0);

        pushPrank(lp.implementation().owner());
        lp.setPaused(true);
        lp.setParameters(address(0), 1e14, 1, 1, 0, 0, 0, 0);
        popPrank();
    }
}

contract MIMSwapRouterAddLiquidityOneSideTest is BaseTest {
    using SafeTransferLib for address;
    uint256 adjustedBaseAmount;
    uint256 adjustedQuoteAmount;
    uint256 share;
    uint256 swapOutAmount;
    uint256 baseRefundAmount;
    uint256 quoteRefundAmount;
    address mim;
    address dai;
    MagicLP lp;
    Router router;

    address constant DAI_WHALE = 0xd85E038593d7A098614721EaE955EC2022B9B91B;
    address constant MIM_WHALE = 0x27807dD7ADF218e1f4d885d54eD51C70eFb9dE50;

    function setUp() public override {
        fork(ChainId.Arbitrum, 237490173);
        super.setUp();

        mim = toolkit.getAddress(block.chainid, "mim");
        dai = toolkit.getAddress(block.chainid, "dai");

        router = Router(payable(toolkit.getAddress("mimswap.router")));

        pushPrank(MIM_WHALE);
        mim.safeTransfer(bob, 10_000_000 ether);
        popPrank();

        pushPrank(bob);
        mim.safeApprove(address(router), type(uint256).max);
        popPrank();

        pushPrank(DAI_WHALE);
        dai.safeTransfer(bob, 10_000_000 ether);
        popPrank();

        pushPrank(bob);
        dai.safeApprove(address(router), type(uint256).max);
        popPrank();

        pushPrank(bob);
        (address clone, ) = router.createPool(mim, dai, 1e14, 1e18, 250000000000000, address(0), 7308329318736220285222548, 914298524486040690505430, true);
        popPrank();

        lp = MagicLP(clone);

        assertEq(mim.balanceOf(carol), 0, "carol should have 0 MIM");
        assertEq(dai.balanceOf(carol), 0, "carol should have 0 dai");
        assertEq(lp.balanceOf(carol), 0, "carol should have 0 LP");
    }

    function _clearOutTokens(address account, address token) internal {
        uint balance = token.balanceOf(account);
        if (balance > 0) {
            token.safeTransfer(address(BURN_ADDRESS), balance);
        }
    }

    function testBasicAddLiquidityOneSideFromBaseToken() public {
        _clearOutTokens(carol, mim);
        _clearOutTokens(carol, dai);

        deal(mim, carol, 100_000 ether, true);

        pushPrank(carol);
        mim.safeApprove(address(router), type(uint256).max);

        uint256 mimSumBefore = mim.balanceOf(carol) + mim.balanceOf(address(lp));
        uint256 daiSumBefore = dai.balanceOf(carol) + dai.balanceOf(address(lp)) + dai.balanceOf(toolkit.getAddress("safe.yields"));

        AddLiquidityOneSideParams memory params = AddLiquidityOneSideParams(
            address(lp),
            carol,
            true,
            100_000 ether,
            11_120 ether,
            0,
            type(uint256).max
        );

        vm.recordLogs();

        (adjustedBaseAmount, adjustedQuoteAmount, share, swapOutAmount, baseRefundAmount, quoteRefundAmount) = router.addLiquidityOneSide(params);

        assertEq(lp.balanceOf(carol), share);

        // Assert no tokens left in the router
        assertEq(mim.balanceOf(address(router)), 0);
        assertEq(dai.balanceOf(address(router)), 0);

        // Assert tokens are in the expected addresses
        assertEq(mim.balanceOf(carol) + mim.balanceOf(address(lp)), mimSumBefore);
        assertEq(dai.balanceOf(carol) + dai.balanceOf(address(lp)) + dai.balanceOf(toolkit.getAddress("safe.yields")), daiSumBefore);

        // Check Transfer logs match refunded amounts
        {
          Vm.Log[] memory entries = vm.getRecordedLogs();
          uint256 refundIndex = entries.length - 1;
          if (quoteRefundAmount > 0) {
              Vm.Log memory refundTransfer = entries[refundIndex];

              assertEq(refundTransfer.topics[0], 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef); // keccak256(bytes("Transfer(address,address,uint256)"))
              assertEq(refundTransfer.topics[1], bytes32(abi.encode(router)));
              assertEq(refundTransfer.topics[2], bytes32(abi.encode(carol)));
              assertEq(refundTransfer.data, abi.encode(quoteRefundAmount));

              --refundIndex;
          }
          if (baseRefundAmount > 0) {
              Vm.Log memory refundTransfer = entries[refundIndex];

              assertEq(refundTransfer.topics[0], 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef); // keccak256(bytes("Transfer(address,address,uint256)"))
              assertEq(refundTransfer.topics[1], bytes32(abi.encode(router)));
              assertEq(refundTransfer.topics[2], bytes32(abi.encode(carol)));
              assertEq(refundTransfer.data, abi.encode(baseRefundAmount));
          }
        }

        assertApproxEqAbs(mim.balanceOf(carol), 0 ether, 160 ether, "too much base refunded");
        assertApproxEqAbs(dai.balanceOf(carol), 0 ether, 160 ether, "too much quote refunded");

        lp.approve(address(router), share);

        uint256 snapshot = vm.snapshot();

        // Remove liqudity and compare the amounts
        (uint adjustedBaseAmount2, uint adjustedQuoteAmount2) = router.removeLiquidity(address(lp), carol, share, 0, 0, type(uint256).max);

        assertApproxEqAbs(adjustedBaseAmount, adjustedBaseAmount2, 0.1 ether);
        assertApproxEqAbs(adjustedQuoteAmount, adjustedQuoteAmount2, 0.1 ether);

        console2.log("mim out", toolkit.formatDecimals(mim.balanceOf(carol)));
        console2.log("dai out", toolkit.formatDecimals(dai.balanceOf(carol)));

        assertApproxEqAbs(
            mim.balanceOf(carol) + dai.balanceOf(carol),
            100_000 ether,
            100 ether,
            "carol should have around $100_000 worth of assets"
        );

        vm.revertTo(snapshot);

        _clearOutTokens(carol, mim);
        _clearOutTokens(carol, dai);

        uint256 amountOut = router.removeLiquidityOneSide(address(lp), carol, true, share, 0, type(uint256).max);

        assertEq(amountOut, mim.balanceOf(carol));
        assertApproxEqAbs(mim.balanceOf(carol), 100_000 ether, 150 ether, "carol should have around 100_000 MIM");
        assertEq(dai.balanceOf(carol), 0 ether, "carol should have 0 dai");

        popPrank();
    }

    function testBasicAddLiquidityOneSideFromQuoteToken() public {
        _clearOutTokens(carol, mim);
        _clearOutTokens(carol, dai);

        pushPrank(DAI_WHALE);
        dai.safeTransfer(carol, 100_000 ether);
        popPrank();

        pushPrank(carol);
        dai.safeApprove(address(router), type(uint256).max);

        uint256 mimSumBefore = mim.balanceOf(carol) + mim.balanceOf(address(lp)) + mim.balanceOf(toolkit.getAddress("safe.yields"));
        uint256 daiSumBefore = dai.balanceOf(carol) + dai.balanceOf(address(lp));

        assertEq(dai.balanceOf(carol), 100_000 ether, "carol should have 100_000 dai");

        AddLiquidityOneSideParams memory params = AddLiquidityOneSideParams(
            address(lp),
            carol,
            false,
            100_000 ether,
            87_780 ether,
            0,
            type(uint256).max
        );

        vm.recordLogs();

        (adjustedBaseAmount, adjustedQuoteAmount, share, swapOutAmount, baseRefundAmount, quoteRefundAmount) = router.addLiquidityOneSide(params);

        assertEq(lp.balanceOf(carol), share);

        // Assert no tokens left in the router
        assertEq(mim.balanceOf(address(router)), 0);
        assertEq(dai.balanceOf(address(router)), 0);

        // Assert tokens are in the expected addresses
        assertEq(mim.balanceOf(carol) + mim.balanceOf(address(lp)) + mim.balanceOf(toolkit.getAddress("safe.yields")), mimSumBefore);
        assertEq(dai.balanceOf(carol) + dai.balanceOf(address(lp)), daiSumBefore);

        // Check Transfer logs match refunded amounts
        {
          Vm.Log[] memory entries = vm.getRecordedLogs();
          uint256 refundIndex = entries.length - 1;
          if (quoteRefundAmount > 0) {
              Vm.Log memory refundTransfer = entries[refundIndex];

              assertEq(refundTransfer.topics[0], 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef); // keccak256(bytes("Transfer(address,address,uint256)"))
              assertEq(refundTransfer.topics[1], bytes32(abi.encode(router)));
              assertEq(refundTransfer.topics[2], bytes32(abi.encode(carol)));
              assertEq(refundTransfer.data, abi.encode(quoteRefundAmount));

              --refundIndex;
          }
          if (baseRefundAmount > 0) {
              Vm.Log memory refundTransfer = entries[refundIndex];

              assertEq(refundTransfer.topics[0], 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef); // keccak256(bytes("Transfer(address,address,uint256)"))
              assertEq(refundTransfer.topics[1], bytes32(abi.encode(router)));
              assertEq(refundTransfer.topics[2], bytes32(abi.encode(carol)));
              assertEq(refundTransfer.data, abi.encode(baseRefundAmount));
          }
        }

        assertApproxEqAbs(mim.balanceOf(carol), 0 ether, 100 ether, "too much base refunded");
        assertApproxEqAbs(dai.balanceOf(carol), 0 ether, 100 ether, "too much quote refunded");

        // Remove liqudity and compare the amounts
        lp.approve(address(router), share);

        uint256 snapshot = vm.snapshot();
        (uint adjustedBaseAmount2, uint adjustedQuoteAmount2) = router.removeLiquidity(address(lp), carol, share, 0, 0, type(uint256).max);

        assertApproxEqAbs(adjustedBaseAmount, adjustedBaseAmount2, 0.1 ether);
        assertApproxEqAbs(adjustedQuoteAmount, adjustedQuoteAmount2, 0.1 ether);

        console2.log("mim balance after", toolkit.formatDecimals(mim.balanceOf(carol)));
        console2.log("dai balance after", toolkit.formatDecimals(dai.balanceOf(carol)));

        // Got more MIM back because dai is worth more
        assertApproxEqAbs(
            mim.balanceOf(carol) + dai.balanceOf(carol),
            100_000 ether,
            350 ether,
            "carol should have around $100_000 worth of assets"
        );

        vm.revertTo(snapshot);

        _clearOutTokens(carol, mim);
        _clearOutTokens(carol, dai);

        uint256 amountOut = router.removeLiquidityOneSide(address(lp), carol, false, share, 0, type(uint256).max);

        assertEq(amountOut, dai.balanceOf(carol));
        assertApproxEqAbs(dai.balanceOf(carol), 100_000 ether, 160 ether, "carol should have around 100_000 dai");
        assertEq(mim.balanceOf(carol), 0 ether, "carol should have 0 MIM");
        popPrank();
    }

    function testBasicAddLiquidityImbalancedQuote() public {
        _clearOutTokens(carol, mim);
        _clearOutTokens(carol, dai);

        pushPrank(DAI_WHALE);
        dai.safeTransfer(carol, 50_000 ether);
        popPrank();

        deal(mim, carol, 100_000 ether, true);

        pushPrank(carol);
        dai.safeApprove(address(router), type(uint256).max);
        mim.safeApprove(address(router), type(uint256).max);

        assertEq(mim.balanceOf(carol), 100_000 ether, "carol should have 100_000 MIM");
        assertEq(dai.balanceOf(carol), 50_000 ether, "carol should have 50_000 dai");

        uint256 mimSumBefore = mim.balanceOf(carol) + mim.balanceOf(address(lp)) + mim.balanceOf(toolkit.getAddress("safe.yields"));
        uint256 daiSumBefore = dai.balanceOf(carol) + dai.balanceOf(address(lp));

        AddLiquidityImbalancedParams memory params = AddLiquidityImbalancedParams(
            address(lp),
            carol,
            100_000 ether,
            50_000 ether,
            false,
            32_695 ether,
            0,
            type(uint256).max
        );

        vm.recordLogs();

        (adjustedBaseAmount, adjustedQuoteAmount, share, swapOutAmount, baseRefundAmount, quoteRefundAmount) = router
            .addLiquidityImbalanced(params);

        assertEq(lp.balanceOf(carol), share);

        // Assert no tokens left in the router
        assertEq(mim.balanceOf(address(router)), 0);
        assertEq(dai.balanceOf(address(router)), 0);

        // Assert tokens are in the expected addresses
        assertEq(mim.balanceOf(carol) + mim.balanceOf(address(lp)) + mim.balanceOf(toolkit.getAddress("safe.yields")), mimSumBefore);
        assertEq(dai.balanceOf(carol) + dai.balanceOf(address(lp)), daiSumBefore);

        // Check Transfer logs match refunded amounts
        {
          Vm.Log[] memory entries = vm.getRecordedLogs();
          uint256 refundIndex = entries.length - 1;
          if (quoteRefundAmount > 0) {
              Vm.Log memory refundTransfer = entries[refundIndex];

              assertEq(refundTransfer.topics[0], 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef); // keccak256(bytes("Transfer(address,address,uint256)"))
              assertEq(refundTransfer.topics[1], bytes32(abi.encode(router)));
              assertEq(refundTransfer.topics[2], bytes32(abi.encode(carol)));
              assertEq(refundTransfer.data, abi.encode(quoteRefundAmount));

              --refundIndex;
          }
          if (baseRefundAmount > 0) {
              Vm.Log memory refundTransfer = entries[refundIndex];

              assertEq(refundTransfer.topics[0], 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef); // keccak256(bytes("Transfer(address,address,uint256)"))
              assertEq(refundTransfer.topics[1], bytes32(abi.encode(router)));
              assertEq(refundTransfer.topics[2], bytes32(abi.encode(carol)));
              assertEq(refundTransfer.data, abi.encode(baseRefundAmount));
          }
        }

        assertApproxEqAbs(mim.balanceOf(carol), 0 ether, 100 ether, "too much base refunded");
        assertApproxEqAbs(dai.balanceOf(carol), 0 ether, 100 ether, "too much quote refunded");

        // Remove liqudity and compare the amounts
        lp.approve(address(router), share);

        (uint adjustedBaseAmount2, uint adjustedQuoteAmount2) = router.removeLiquidity(address(lp), carol, share, 0, 0, type(uint256).max);

        assertApproxEqAbs(adjustedBaseAmount, adjustedBaseAmount2, 0.1 ether);
        assertApproxEqAbs(adjustedQuoteAmount, adjustedQuoteAmount2, 0.1 ether);

        console2.log("mim balance after", toolkit.formatDecimals(mim.balanceOf(carol)));
        console2.log("dai balance after", toolkit.formatDecimals(dai.balanceOf(carol)));

        // Got more MIM back because dai is worth more
        assertApproxEqAbs(
            mim.balanceOf(carol) + dai.balanceOf(carol),
            150_000 ether,
            150 ether,
            "carol should have around $150_000 worth of assets"
        );
    }

    function testBasicAddLiquidityImbalancedBase() public {
        _clearOutTokens(carol, mim);
        _clearOutTokens(carol, dai);

        pushPrank(DAI_WHALE);
        dai.safeTransfer(carol, 1_000 ether);
        popPrank();

        deal(mim, carol, 100_000 ether, true);

        pushPrank(carol);
        dai.safeApprove(address(router), type(uint256).max);
        mim.safeApprove(address(router), type(uint256).max);

        uint256 mimSumBefore = mim.balanceOf(carol) + mim.balanceOf(address(lp));
        uint256 daiSumBefore = dai.balanceOf(carol) + dai.balanceOf(address(lp)) + dai.balanceOf(toolkit.getAddress("safe.yields"));

        assertEq(mim.balanceOf(carol), 100_000 ether, "carol should have 100_000 MIM");
        assertEq(dai.balanceOf(carol), 1_000 ether, "carol should have 1_000 dai");

        AddLiquidityImbalancedParams memory params = AddLiquidityImbalancedParams(
            address(lp),
            carol,
            100_000 ether,
            1_000 ether,
            true,
            10_200 ether,
            0,
            type(uint256).max
        );

        vm.recordLogs();

        (adjustedBaseAmount, adjustedQuoteAmount, share, swapOutAmount, baseRefundAmount, quoteRefundAmount) = router
            .addLiquidityImbalanced(params);

        assertEq(lp.balanceOf(carol), share);

        // Assert no tokens left in the router
        assertEq(mim.balanceOf(address(router)), 0);
        assertEq(dai.balanceOf(address(router)), 0);

        // Assert tokens are in the expected addresses
        assertEq(mim.balanceOf(carol) + mim.balanceOf(address(lp)), mimSumBefore);
        assertEq(dai.balanceOf(carol) + dai.balanceOf(address(lp)) + dai.balanceOf(toolkit.getAddress("safe.yields")), daiSumBefore);

        // Check Transfer logs match refunded amounts
        {
          Vm.Log[] memory entries = vm.getRecordedLogs();
          uint256 refundIndex = entries.length - 1;
          if (quoteRefundAmount > 0) {
              Vm.Log memory refundTransfer = entries[refundIndex];

              assertEq(refundTransfer.topics[0], 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef); // keccak256(bytes("Transfer(address,address,uint256)"))
              assertEq(refundTransfer.topics[1], bytes32(abi.encode(router)));
              assertEq(refundTransfer.topics[2], bytes32(abi.encode(carol)));
              assertEq(refundTransfer.data, abi.encode(quoteRefundAmount));

              --refundIndex;
          }
          if (baseRefundAmount > 0) {
              Vm.Log memory refundTransfer = entries[refundIndex];

              assertEq(refundTransfer.topics[0], 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef); // keccak256(bytes("Transfer(address,address,uint256)"))
              assertEq(refundTransfer.topics[1], bytes32(abi.encode(router)));
              assertEq(refundTransfer.topics[2], bytes32(abi.encode(carol)));
              assertEq(refundTransfer.data, abi.encode(baseRefundAmount));
          }
        }

        assertApproxEqAbs(mim.balanceOf(carol), 0 ether, 106 ether, "too much base refunded");
        assertApproxEqAbs(dai.balanceOf(carol), 0 ether, 106 ether, "too much quote refunded");

        // Remove liqudity and compare the amounts
        lp.approve(address(router), share);

        (uint adjustedBaseAmount2, uint adjustedQuoteAmount2) = router.removeLiquidity(address(lp), carol, share, 0, 0, type(uint256).max);

        assertApproxEqAbs(adjustedBaseAmount, adjustedBaseAmount2, 0.1 ether);
        assertApproxEqAbs(adjustedQuoteAmount, adjustedQuoteAmount2, 0.1 ether);

        console2.log("mim balance after", toolkit.formatDecimals(mim.balanceOf(carol)));
        console2.log("dai balance after", toolkit.formatDecimals(dai.balanceOf(carol)));

        // Got more MIM back because dai is worth more
        assertApproxEqAbs(
            mim.balanceOf(carol) + dai.balanceOf(carol),
            101_000 ether,
            100 ether,
            "carol should have around $101_000 worth of assets"
        );
    }
}

/// @custom:halmos --storage-layout=generic
contract MIMSwapSymTest is Test {
    ERC20Mock mim;
    ERC20Mock dai;

    FeeRateModel feeRateModel;
    MagicLP implementation;

    function setUp() public {
        mim = new ERC20Mock("MIM", "MIM");
        dai = new ERC20Mock("dai", "dai");

        feeRateModel = new FeeRateModel(makeAddr("Maintainer"), address(0));
        implementation = newMagicLP();
    }

    function proveFeeModel(uint256 lpFeeRate) public view {
        vm.assume(lpFeeRate >= implementation.MIN_LP_FEE_RATE());
        vm.assume(lpFeeRate <= implementation.MAX_LP_FEE_RATE());
        (uint256 adjustedLpFeeRate, uint256 mtFeeRate) = feeRateModel.getFeeRate(address(0), lpFeeRate);

        assertEq(adjustedLpFeeRate + mtFeeRate, lpFeeRate);
    }
}

contract SymbolicMockFactory is SymTest {
    function poolExists(address /*pool*/) external pure returns (bool) {
        return svm.createBool("poolExists");
    }
}

contract SymbolicMockLp is SymTest {
    address public _BASE_TOKEN_;
    address public _QUOTE_TOKEN_;

    constructor(address baseToken, address quoteToken) {
        _BASE_TOKEN_ = baseToken;
        _QUOTE_TOKEN_ = quoteToken;
    }

    function sellBase(address /*to*/) external pure returns (uint256 receiveQuoteAmount) {
        return svm.createUint256("receiveBaseAmount");
    }

    function sellQuote(address /*to*/) external pure returns (uint256 receiveBaseAmount) {
        return svm.createUint256("quoteReceiveAmount");
    }
}

contract RouterSymTest is Test, SymTest {
    Router router;

    MockWETH baseToken;
    ERC20Mock quoteToken;

    function setUp() public {
        baseToken = new MockWETH("WETH", "Wrapped Ethereum");
        quoteToken = new ERC20Mock("QuoteToken", "QT");
        quoteToken.setDecimals(18);
        router = new Router(IWETH(address(baseToken)), IFactory(address(new SymbolicMockFactory())));
    }

    function _proveBalanceInvariant(address other, bytes memory encodedCall) internal {
        address caller = svm.createAddress("caller");
        vm.assume(other != address(0));
        vm.assume(other != address(router));
        vm.assume(caller != address(0));
        vm.assume(caller != other);

        uint256 otherBaseBalance = svm.createUint256("otherBaseBalance");
        uint256 otherQuoteBalance = svm.createUint256("otherQuoteBalance");
        uint256 otherNativeTokenBalance = svm.createUint256("otherNativeTokenBalance");

        vm.deal(other, otherBaseBalance);
        vm.prank(other);
        baseToken.deposit{value: otherBaseBalance}();
        uint256 before = baseToken.balanceOf(other);
        quoteToken.mint(other, otherQuoteBalance);
        vm.deal(other, otherNativeTokenBalance);

        uint256 callerBaseBalance = svm.createUint256("callerBaseBalance");
        vm.deal(caller, callerBaseBalance);
        vm.prank(caller);
        baseToken.deposit{value: callerBaseBalance}();
        quoteToken.mint(caller, svm.createUint256("callerQuoteBalance"));
        vm.deal(caller, svm.createUint256("callerNativeTokenBalance"));

        vm.prank(other);
        baseToken.approve(address(router), svm.createUint256("otherBaseRouterApproval"));
        vm.prank(other);
        quoteToken.approve(address(router), svm.createUint256("otherQuoteRouterApproval"));

        vm.prank(caller);
        baseToken.approve(address(router), svm.createUint256("callerBaseRouterApproval"));
        vm.prank(caller);
        quoteToken.approve(address(router), svm.createUint256("callerQuoteRouterApproval"));

        vm.prank(caller);
        (bool success, ) = address(router).call{value: svm.createUint256("value")}(encodedCall);

        vm.assume(success);

        assertGe(baseToken.balanceOf(other), before);
        assertGe(quoteToken.balanceOf(other), otherQuoteBalance);
        assertGe(other.balance, otherNativeTokenBalance);
    }

    function _createPath(address other, uint256 pathLength) internal returns (address[] memory path) {
        path = new address[](pathLength);
        for (uint256 i = 0; i < pathLength; ++i) {
            path[i] = address(new SymbolicMockLp(address(baseToken), address(quoteToken)));
            vm.assume(other != path[i]);
        }
    }

    function _proveBalanceInvariantDirect() internal {
        address other = svm.createAddress("other");

        address lp = address(new SymbolicMockLp(address(baseToken), address(quoteToken)));
        vm.assume(other != lp);

        bytes4 selector = svm.createBytes4("selector");
        if (selector == Router.sellBaseETHForTokens.selector) {
            _proveBalanceInvariant(
                other,
                abi.encodeCall(
                    Router.sellBaseETHForTokens,
                    (lp, svm.createAddress("to"), svm.createUint256("minimumOut"), svm.createUint256("deadline"))
                )
            );
        } else if (selector == Router.sellBaseTokensForETH.selector) {
            _proveBalanceInvariant(
                other,
                abi.encodeCall(
                    Router.sellBaseTokensForETH,
                    (
                        lp,
                        svm.createAddress("to"),
                        svm.createUint256("amountIn"),
                        svm.createUint256("minimumOut"),
                        svm.createUint256("deadline")
                    )
                )
            );
        } else if (selector == Router.sellBaseTokensForTokens.selector) {
            _proveBalanceInvariant(
                other,
                abi.encodeCall(
                    Router.sellBaseTokensForTokens,
                    (
                        lp,
                        svm.createAddress("to"),
                        svm.createUint256("amountIn"),
                        svm.createUint256("minimumOut"),
                        svm.createUint256("deadline")
                    )
                )
            );
        } else if (selector == Router.sellQuoteETHForTokens.selector) {
            _proveBalanceInvariant(
                other,
                abi.encodeCall(
                    Router.sellQuoteETHForTokens,
                    (lp, svm.createAddress("to"), svm.createUint256("minimumOut"), svm.createUint256("deadline"))
                )
            );
        } else if (selector == Router.sellQuoteTokensForETH.selector) {
            _proveBalanceInvariant(
                other,
                abi.encodeCall(
                    Router.sellQuoteTokensForETH,
                    (
                        lp,
                        svm.createAddress("to"),
                        svm.createUint256("amountIn"),
                        svm.createUint256("minimumOut"),
                        svm.createUint256("deadline")
                    )
                )
            );
        } else if (selector == Router.sellQuoteTokensForTokens.selector) {
            _proveBalanceInvariant(
                other,
                abi.encodeCall(
                    Router.sellQuoteTokensForTokens,
                    (
                        lp,
                        svm.createAddress("to"),
                        svm.createUint256("amountIn"),
                        svm.createUint256("minimumOut"),
                        svm.createUint256("deadline")
                    )
                )
            );
        }
    }

    function _proveBalanceInvariantWithPath(uint256 pathLength) internal {
        address other = svm.createAddress("other");

        address[] memory path = _createPath(other, pathLength);

        bytes4 selector = svm.createBytes4("selector");
        if (selector == Router.swapETHForTokens.selector) {
            _proveBalanceInvariant(
                other,
                abi.encodeCall(
                    Router.swapETHForTokens,
                    (
                        svm.createAddress("to"),
                        path,
                        svm.createUint256("directions"),
                        svm.createUint256("minimumOut"),
                        svm.createUint256("deadline")
                    )
                )
            );
        } else if (selector == Router.swapTokensForETH.selector) {
            _proveBalanceInvariant(
                other,
                abi.encodeCall(
                    Router.swapTokensForETH,
                    (
                        svm.createAddress("to"),
                        svm.createUint256("inAmount"),
                        path,
                        svm.createUint256("directions"),
                        svm.createUint256("minimumOut"),
                        svm.createUint256("deadline")
                    )
                )
            );
        } else if (selector == Router.swapTokensForTokens.selector) {
            _proveBalanceInvariant(
                other,
                abi.encodeCall(
                    Router.swapTokensForTokens,
                    (
                        svm.createAddress("to"),
                        svm.createUint256("inAmount"),
                        path,
                        svm.createUint256("directions"),
                        svm.createUint256("minimumOut"),
                        svm.createUint256("deadline")
                    )
                )
            );
        }
    }

    enum Kind {
        DIRECT,
        PATH
    }

    /// @custom:halmos --loop=4 --solver-timeout-assertion=180000
    function proveBalanceInvariant(Kind kind) public {
        if (kind == Kind.DIRECT) {
            _proveBalanceInvariantDirect();
        } else if (kind == Kind.PATH) {
            uint256 pathLength = svm.createUint256("pathLength");
            if (pathLength == 0) {
                _proveBalanceInvariantWithPath(0);
            } else if (pathLength == 1) {
                _proveBalanceInvariantWithPath(1);
            } else if (pathLength == 2) {
                _proveBalanceInvariantWithPath(2);
            } else if (pathLength == 3) {
                _proveBalanceInvariantWithPath(3);
            } else if (pathLength == 4) {
                _proveBalanceInvariantWithPath(4);
            }
        }
    }
}
