// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseTest.sol";
import {ERC20Mock} from "openzeppelin-contracts/mocks/ERC20Mock.sol";
import {WETH} from "solady/tokens/WETH.sol";
import {FeeRateModel} from "/mimswap/auxiliary/FeeRateModel.sol";
import {IWETH} from "interfaces/IWETH.sol";
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
        uint256 amountOut = router.sellBaseTokensForTokens(address(lp1), 1 ether, 0, type(uint256).max);
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
        router.swapTokensForTokens(1 ether, path, directions, 1, type(uint256).max);
    }
}
