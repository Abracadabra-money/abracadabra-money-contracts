// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MIMSwap.s.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {BlastMagicLP} from "/blast/BlastMagicLP.sol";
import {BlastTokenMock} from "utils/mocks/BlastMock.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {IFeeRateModel} from "/mimswap/interfaces/IFeeRateModel.sol";
import {WETH} from "solady/tokens/WETH.sol";
import {IWETH} from "interfaces/IWETH.sol";
import {IMagicLP} from "/mimswap/interfaces/IMagicLP.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {IFactory} from "/mimswap/interfaces/IFactory.sol";

function newMagicLP() returns (MagicLP) {
    return new MagicLP(address(tx.origin));
}

uint256 constant MIN_LP_FEE_RATE = 1e14;

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

    address constant BLAST_PRECOMPILE = 0x4300000000000000000000000000000000000002;

    address mim;
    address usdb;
    address feeCollector;
    BlastTokenRegistry blastTokenRegistry;

    function setUp() public override {
        MIMSwapScript script = super.initialize(ChainId.Blast, 203996);
        (implementation, feeRateModel, factory, router) = script.deploy();

        mim = toolkit.getAddress(ChainId.Blast, "mim");
        usdb = toolkit.getAddress(ChainId.Blast, "usdb");

        feeCollector = BlastMagicLP(address(implementation)).feeTo();
        blastTokenRegistry = BlastMagicLP(address(implementation)).registry();

        super.afterDeployed();
    }

    function testFuzzFeeModel(uint256 lpFeeRate) public {
        lpFeeRate = bound(lpFeeRate, implementation.MIN_LP_FEE_RATE(), implementation.MAX_LP_FEE_RATE());
        (uint256 adjustedLpFeeRate, uint256 mtFeeRate) = feeRateModel.getFeeRate(address(0), lpFeeRate);

        assertEq(adjustedLpFeeRate + mtFeeRate, lpFeeRate);
    }

    function testRescueFunds() public {
        BlastMagicLP lp = _createDefaultLp(false);

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
        lp.rescue(usdb, alice, 1 ether);

        uint balanceBefore = token.balanceOf(alice);
        uint balanceBeforeLP = token.balanceOf(address(lp));

        lp.rescue(address(token), alice, 1 ether);
        assertEq(token.balanceOf(alice), balanceBefore + 1 ether);
        assertEq(token.balanceOf(address(lp)), balanceBeforeLP - 1 ether);

        vm.expectRevert();
        lp.rescue(address(token), alice, 1 ether);
        popPrank();
    }

    function testOnlyCallableOnClones() public {
        BlastMagicLP lp = _createDefaultLp(false);
        BlastMagicLP _implementation = BlastMagicLP(address(lp.implementation()));

        vm.expectRevert(abi.encodeWithSignature("ErrNotClone()"));
        _implementation.claimGasYields();
        vm.expectRevert(abi.encodeWithSignature("ErrNotClone()"));
        _implementation.updateTokenClaimables();

        vm.expectRevert(abi.encodeWithSignature("ErrNotAllowedImplementationOperator()"));
        lp.claimTokenYields();
        vm.expectRevert(abi.encodeWithSignature("ErrNotAllowedImplementationOperator()"));
        lp.updateTokenClaimables();
    }

    function testOnlyCallableOnImplementation() public {
        BlastMagicLP lp = _createDefaultLp(false);
        BlastMagicLP _implementation = BlastMagicLP(address(lp.implementation()));

        vm.expectRevert(abi.encodeWithSignature("ErrNotImplementation()"));
        lp.setFeeTo(bob);
        vm.expectRevert(abi.encodeWithSignature("ErrNotImplementation()"));
        lp.setOperator(bob, true);

        vm.expectRevert(abi.encodeWithSignature("ErrNotImplementationOwner()"));
        _implementation.setFeeTo(bob);
        vm.expectRevert(abi.encodeWithSignature("ErrNotImplementationOwner()"));
        _implementation.setOperator(bob, true);
    }

    function testClaimYields() public {
        BlastMock(0x4300000000000000000000000000000000000002).enableYieldTokenMocks();

        BlastMagicLP lp = _createDefaultLp(false);
        BlastMagicLP _implementation = BlastMagicLP(address(lp.implementation()));

        // Simulate gas yield
        BlastMock(BLAST_PRECOMPILE).addClaimableGas(address(lp), 1 ether);
        uint256 balanceBefore = feeCollector.balance;

        pushPrank(_implementation.owner());
        // Try claiming token yields without registering yield tokens
        // should only claim gas yields
        lp.claimGasYields();
        popPrank();
        assertEq(feeCollector.balance, balanceBefore + 1 ether, "Gas yield not claimed");

        // Enable claimable on USDB
        pushPrank(blastTokenRegistry.owner());
        blastTokenRegistry.setNativeYieldTokenEnabled(usdb, true);
        popPrank();

        pushPrank(_implementation.owner());
        // yield token enabled, but not updated on the lp
        vm.expectRevert(abi.encodeWithSignature("NotClaimableAccount()"));
        lp.claimTokenYields();

        // Update
        lp.updateTokenClaimables();

        // simulate token yields
        BlastTokenMock(usdb).addClaimable(address(lp), 1 ether);
        balanceBefore = usdb.balanceOf(feeCollector);

        // Now should work
        lp.claimTokenYields();

        assertEq(usdb.balanceOf(feeCollector), balanceBefore + 1 ether);
        popPrank();
    }

    function _createDefaultLp(bool pol) internal returns (BlastMagicLP lp) {
        lp = BlastMagicLP(factory.create(mim, usdb, MIN_LP_FEE_RATE, 997724689700000000, 100000000000000, pol));

        assertNotEq(address(lp.implementation()), address(0));
        assertEq(lp.feeTo(), address(0));
        assertEq(lp.owner(), address(0));
        assertNotEq(BlastMagicLP(address(lp.implementation())).feeTo(), address(0));
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
        vm.chainId(ChainId.Blast);
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
        vm.chainId(ChainId.Blast);
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

        // ErrDecimalsDifferenceTooLarge
        base.setDecimals(8);
        quote.setDecimals(24);
        vm.expectRevert(abi.encodeWithSignature("ErrDecimalsDifferenceTooLarge()"));
        router.createPool(address(base), address(quote), 0, 0, 0, address(0), 0, 0, false);

        base.setDecimals(18);
        quote.setDecimals(18);
        // means it went past the decimal checks
        vm.expectRevert(abi.encodeWithSignature("ErrInvalidI()"));
        router.createPool(address(base), address(quote), 0, 0, 0, address(0), 0, 0, false);
    }
}

contract RouterUnitTest is Test {
    error ErrTooHighSlippage(uint256 amountOut);
    error ErrExpired();

    address weth;
    Router router;

    function setUp() public {
        weth = makeAddr("WETH");

        MagicLP lp = newMagicLP();
        address maintainer = makeAddr("Maintainer");
        address factoryOwner = makeAddr("FactoryOwner");
        FeeRateModel maintainerFeeRateModel = new FeeRateModel(maintainer, address(0));
        Factory factory = new Factory(address(lp), IFeeRateModel(address(maintainerFeeRateModel)), factoryOwner);

        router = new Router(IWETH(weth), IFactory(address(factory)));
    }

    struct PathDataEntry {
        address lp;
        address baseToken;
        address quoteToken;
        bool sellQuote;
        uint256 amountOut;
    }

    /// forge-config: default.fuzz.runs = 65536
    function testEnsureDeadlineRevert(
        address lp,
        address to,
        uint256 amountIn,
        uint256 minimumOut,
        uint256 deadline,
        uint256 afterDeadline
    ) public {
        vm.assume(deadline != type(uint256).max);
        afterDeadline = _bound(afterDeadline, deadline + 1, type(uint256).max);
        vm.warp(afterDeadline);
        vm.expectRevert(ErrExpired.selector);
        router.sellQuoteTokensForTokens(lp, to, amountIn, minimumOut, deadline);
    }

    function _addPool(IFactory _factory, MagicLP _lp) private {
        vm.startPrank(Owned(address(_factory)).owner());
        IFactory(_factory).addPool(address(0x1), _lp._BASE_TOKEN_(), _lp._QUOTE_TOKEN_(), address(_lp));
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 10000
    function testSwapRouter(address to, uint256 amountIn, PathDataEntry[] calldata pathData, uint256 minimumOut) public {
        vm.assume(pathData.length > 0 && pathData.length <= 256);

        address[] memory path = new address[](pathData.length);
        uint256 directions = 0;

        address inToken = pathData[0].sellQuote ? pathData[0].quoteToken : pathData[0].baseToken;
        // Assume inToken not VM_ADDRESS nor precompile
        vm.assume(inToken != VM_ADDRESS && uint160(inToken) > 0xff);

        amountIn = bound(amountIn, 0, type(uint112).max);

        vm.expectCall(inToken, abi.encodeCall(IERC20.transferFrom, (address(this), pathData[0].lp, amountIn)), 1);
        // Ensure code on inToken
        vm.etch(inToken, "");
        vm.mockCall(inToken, abi.encodeCall(IERC20.transferFrom, (address(this), pathData[0].lp, amountIn)), "");

        for (uint256 i = 0; i < pathData.length; ++i) {
            PathDataEntry memory entry = pathData[i];
            // Assume lp not VM_ADDRESS nor precompile
            vm.assume(entry.lp != VM_ADDRESS && uint160(entry.lp) > 0xff);

            // Assume different LP addresses --- to avoid collisions in mockCall/expectCall
            for (uint256 j = 0; j < i; ++j) {
                vm.assume(path[j] != entry.lp);
            }

            bool last = i == pathData.length - 1;

            path[i] = entry.lp;

            bytes memory sellCallEncoded = abi.encodeWithSelector(
                entry.sellQuote ? MagicLP.sellQuote.selector : IMagicLP.sellBase.selector,
                (last ? to : pathData[i + 1].lp)
            );
            vm.expectCall(entry.lp, sellCallEncoded, 1);
            // Ensure code on lp
            vm.etch(entry.lp, "");
            vm.mockCall(entry.lp, sellCallEncoded, abi.encode(entry.amountOut));

            vm.mockCall(entry.lp, abi.encodeCall(IMagicLP._BASE_TOKEN_, ()), abi.encode(entry.baseToken));
            vm.mockCall(entry.lp, abi.encodeCall(IMagicLP._QUOTE_TOKEN_, ()), abi.encode(entry.quoteToken));

            _addPool(router.factory(), MagicLP(entry.lp));

            // Directions are stored in reverse
            directions |= pathData[pathData.length - i - 1].sellQuote ? 1 : 0;
            if (!last) {
                directions <<= 1;
            }
        }

        uint256 expectedOut = pathData[pathData.length - 1].amountOut;
        if (expectedOut < minimumOut) {
            vm.expectRevert(abi.encodeWithSelector(ErrTooHighSlippage.selector, (expectedOut)));
            router.swapTokensForTokens(to, amountIn, path, directions, minimumOut, type(uint256).max);
        } else {
            uint256 outAmount = router.swapTokensForTokens(to, amountIn, path, directions, minimumOut, type(uint256).max);
            assertEq(outAmount, expectedOut);
        }
    }
}

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
        feeRateModel = new FeeRateModel(makeAddr("Maintainer"), address(0));
        MagicLP lpImpl = newMagicLP();
        lp = MagicLP(LibClone.clone(address(lpImpl)));

        lp.init(address(mim), address(usdt), MIN_LP_FEE_RATE, address(feeRateModel), 1_000_000, 500000000000000, true);
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
        assertApproxEqRel(usdt.balanceOf(bob), 50e6, 0.1 ether);

        assertEq(mim.balanceOf(bob), 0);
        uint256 balance = usdt.balanceOf(bob);
        vm.prank(bob);
        usdt.transfer(address(lp), balance);
        lp.sellQuote(bob);
        assertApproxEqRel(mim.balanceOf(bob), 50 ether, 0.00012 ether * 2); // around 0.01% fee for the first and second swap

        assertEq(lp.name(), "MagicLP MIM/USDT");
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
