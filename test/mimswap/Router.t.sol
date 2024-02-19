// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import "utils/BaseTest.sol";
import {ERC20Mock} from "openzeppelin-contracts/mocks/ERC20Mock.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {WETH} from "solady/tokens/WETH.sol";
import {FeeRateModel} from "/mimswap/auxiliary/FeeRateModel.sol";
import {IWETH} from "interfaces/IWETH.sol";
import {IMagicLP} from "/mimswap/interfaces/IMagicLP.sol";
import {MagicLP} from "/mimswap/MagicLP.sol";
import {Router} from "/mimswap/periphery/Router.sol";

contract RouterTest is BaseTest {
    ERC20Mock mim;
    WETH weth;

    FeeRateModel feeRateModel;
    MagicLP lp1;
    MagicLP lp2;
    Router router;

    address feeTo;
    address routerOwner;

    function setUp() public override {
        vm.chainId(ChainId.Blast);
        super.setUp();

        mim = new ERC20Mock();
        weth = new WETH();
        feeRateModel = new FeeRateModel(0, address(0));
        lp1 = new MagicLP();
        lp2 = new MagicLP();

        lp1.init(address(0), address(mim), address(weth), 0, address(feeRateModel), 1 ether, 500000000000000);
        lp2.init(address(0), address(mim), address(weth), 0, address(feeRateModel), 1 ether, 500000000000000);

        mim.mint(address(lp1), 100000 ether);
        deal(address(weth), address(lp1), 100000 ether);
        lp1.buyShares(msg.sender);

        mim.mint(address(lp2), 100000 ether);
        deal(address(weth), address(lp2), 100000 ether);
        lp2.buyShares(msg.sender);

        feeTo = makeAddr("feeTo");
        routerOwner = makeAddr("routerOwner");
        router = new Router(IWETH(address(weth)));
    }

    function testSellBaseTokensForTokens() public {
        mim.mint(alice, 1 ether);
        vm.prank(alice);
        mim.approve(address(router), 1 ether);
        vm.prank(alice);
        uint256 amountOut = router.sellBaseTokensForTokens(alice, address(lp1), 1 ether, 0, type(uint256).max);
        assertEq(weth.balanceOf(alice), amountOut);
        assertApproxEqRel(amountOut, 1 ether, 0.0001e18);
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
        MagicLP lp = new MagicLP();
        lp.init(address(0), address(mim), address(weth), 0, address(feeRateModel), 1 ether, 500000000000000);
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
}

contract RouterUnitTest is Test {
    error ErrExpired();

    address weth;
    Router router;

    function setUp() public {
        weth = makeAddr("WETH");
        router = new Router(IWETH(weth));
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
        afterDeadline = _bound(afterDeadline, deadline == type(uint256).max ? deadline : deadline + 1, type(uint256).max);
        vm.warp(afterDeadline);
        vm.expectRevert(ErrExpired.selector);
        router.sellQuoteTokensForTokens(lp, to, amountIn, minimumOut, deadline);
    }

    function testSwapRouter(address to, uint256 amountIn, PathDataEntry[] calldata pathData, uint256 minimumOut) public {
        vm.assume(pathData.length > 0 && pathData.length <= 256);

        address[] memory path = new address[](pathData.length);
        uint256 directions = 0;

        address inToken = pathData[0].sellQuote ? pathData[0].quoteToken : pathData[0].baseToken;
        // Assume inToken not VM_ADDRESS nor precompile
        vm.assume(inToken != VM_ADDRESS && uint160(inToken) > 0xff);

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

            // Directions are stored in reverse
            directions |= pathData[pathData.length - i - 1].sellQuote ? 1 : 0;
            if (!last) {
                directions <<= 1;
            }
        }

        uint256 expectedOut = pathData[pathData.length - 1].amountOut;

        if (expectedOut < minimumOut) {
            vm.expectRevert();
            router.swapTokensForTokens(to, amountIn, path, directions, minimumOut, type(uint256).max);
        } else {
            uint256 outAmount = router.swapTokensForTokens(to, amountIn, path, directions, minimumOut, type(uint256).max);
            assertEq(outAmount, expectedOut);
        }
    }
}
