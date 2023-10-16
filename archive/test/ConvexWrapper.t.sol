// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "BoringSolidity/ERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/IBentoBoxV1.sol";
import "./mocks/ExchangeRouterMock.sol";
import "script/ConvexCauldrons.s.sol";

abstract contract ConvexWrapperTestBase is BaseTest {
    address constant MIM_WHALE = 0x5f0DeE98360d8200b20812e174d139A1a633EDd2;
    ISwapperV2 swapper;
    ILevSwapperV2 levSwapper;
    ProxyOracle oracle;
    IBentoBoxV1 box;
    IConvexWrapper wrapper;
    ERC20 mim;
    ERC20 curveToken;
    ExchangeRouterMock exchange;
    address curveTokenWhale;
    uint256 expectedOraclePrice;
    ICauldronV4 cauldron;

    function initialize(uint256 _expectedOraclePrice, address _curveTokenWhale) public {
        fork(ChainId.Mainnet, 17198866);
        super.setUp();

        box = IBentoBoxV1(toolkit.getAddress("mainnet.degenBox"));
        mim = ERC20(toolkit.getAddress("mainnet.mim"));
        curveTokenWhale = _curveTokenWhale;

        expectedOraclePrice = _expectedOraclePrice;
        exchange = new ExchangeRouterMock(ERC20(address(0)), ERC20(address(0)));
    }

    function afterInitialize() public {
        curveToken = ERC20(ConvexWrapperLevSwapper(address(swapper)).wrapper().curveToken());
        assertEq(address(curveToken), address(ConvexWrapperLevSwapper(address(levSwapper)).wrapper().curveToken()));

        vm.label(address(wrapper), "convex wrapper");
        vm.label(address(cauldron), "cauldron");
        pushPrank(wrapper.owner());
        wrapper.setCauldron(address(cauldron));
        popPrank();
    }

    function _testLevSwapper(uint256 amount, address recipient) internal virtual;

    function _testSwapper(uint256 shareFrom, address recipient) internal virtual;

    function testOracle() public {
        assertEq(1e36 / oracle.peekSpot(""), expectedOraclePrice);
    }

    function testLevSwapper() public {
        // deposit mim to the lev swapper
        pushPrank(MIM_WHALE);
        uint256 amount = mim.balanceOf(MIM_WHALE);
        //console2.log("mim amount in:", amount);

        mim.transfer(address(box), amount);
        box.deposit(mim, address(box), address(levSwapper), amount, 0);
        popPrank();

        _testLevSwapper(amount, bob);

        uint256 convexWrapperBalance = box.balanceOf(IERC20(address(wrapper)), address(bob));
        //console2.log("convex wrapper out:", convexWrapperBalance);
        assertGt(convexWrapperBalance, 0);
    }

    function testSwapper() public {
        // deposit convex wrapper lp to the swapper
        pushPrank(curveTokenWhale);
        uint256 amount = curveToken.balanceOf(curveTokenWhale);
        //console2.log("curveToken amount in:", amount);
        curveToken.approve(address(wrapper), amount);
        wrapper.deposit(amount, address(box));
        (, uint256 shareFrom) = box.deposit(IERC20(address(wrapper)), address(box), address(swapper), amount, 0);
        popPrank();

        _testSwapper(shareFrom, bob);

        uint256 mimOut = box.balanceOf(mim, address(bob));
        //console2.log("mim out:", mimOut);
        assertGt(mimOut, 0);
    }

    function testConvexRewards() public {
        pushPrank(curveTokenWhale);
        uint256 amount = curveToken.balanceOf(curveTokenWhale);
        curveToken.approve(address(wrapper), amount);
        wrapper.deposit(amount, address(box));
        (, uint256 shareFrom) = box.deposit(IERC20(address(wrapper)), address(box), address(cauldron), amount, 0);

        uint256 crvBalanceBefore = IERC20(wrapper.crv()).balanceOf(address(bob));
        uint256 cvxBalanceBefore = IERC20(wrapper.cvx()).balanceOf(address(bob));

        assertEq(crvBalanceBefore, 0);
        assertEq(cvxBalanceBefore, 0);

        cauldron.addCollateral(bob, true, shareFrom);

        crvBalanceBefore = IERC20(wrapper.crv()).balanceOf(address(bob));
        cvxBalanceBefore = IERC20(wrapper.cvx()).balanceOf(address(bob));
        assertEq(crvBalanceBefore, 0);
        assertEq(cvxBalanceBefore, 0);

        wrapper.getReward(bob);

        crvBalanceBefore = IERC20(wrapper.crv()).balanceOf(address(bob));
        cvxBalanceBefore = IERC20(wrapper.cvx()).balanceOf(address(bob));
        assertEq(crvBalanceBefore, 0);
        assertEq(cvxBalanceBefore, 0);

        advanceTime(30 days);
        wrapper.getReward(bob);

        uint256 crvBalanceAfter = IERC20(wrapper.crv()).balanceOf(address(bob));
        uint256 cvxBalanceAfter = IERC20(wrapper.cvx()).balanceOf(address(bob));

        //console2.log("crv balance:", crvBalanceAfter);
        //console2.log("cvx balance:", cvxBalanceAfter);

        assertGt(crvBalanceAfter, 0);
        assertGt(cvxBalanceAfter, 0);

        wrapper.getReward(bob);
        assertEq(IERC20(wrapper.crv()).balanceOf(address(bob)) - crvBalanceAfter, 0);
        assertEq(IERC20(wrapper.cvx()).balanceOf(address(bob)) - cvxBalanceAfter, 0);

        popPrank();
    }
}

contract Mim3PoolConvextWrapperTest is ConvexWrapperTestBase {
    function setUp() public override {
        super.initialize(1010654680654301882 /* expected oracle price */, 0x66C90baCE2B68955C875FdA89Ba2c5A94e672440);
        ConvexCauldronsScript script = new ConvexCauldronsScript();
        script.setTesting(true);
        (oracle, swapper, levSwapper, wrapper, cauldron) = script.deployMimPool(address(exchange));

        super.afterInitialize();
    }

    function _testLevSwapper(uint256 shareFrom, address recipient) internal override {
        // add liquidity from mim to mim3pool directly without using 0x swapper
        bytes memory data = abi.encode(mim, 0, "");
        levSwapper.swap(recipient, 0, shareFrom, data);
    }

    function _testSwapper(uint256 shareFrom, address recipient) internal override {
        // remove liquidity from mim3pool to mim directly without using 0x swapper
        bytes memory data = abi.encode(0, "");
        swapper.swap(address(0), address(0), recipient, 0, shareFrom, data);
    }
}

contract TriCryptoConvextWrapperTest is ConvexWrapperTestBase {
    using BoringERC20 for ERC20;

    ERC20 usdt;
    address USDT_WHALE = 0x5754284f345afc66a98fbB0a0Afe71e0F007B949;

    function setUp() public override {
        super.initialize(1199268165067124372919 /* expected oracle price */, 0x347140c7F001452e6A60131D24b37103D0e34231);
        ConvexCauldronsScript script = new ConvexCauldronsScript();
        script.setTesting(true);
        (oracle, swapper, levSwapper, wrapper, cauldron) = script.deployTricrypto(address(exchange));

        usdt = ERC20(toolkit.getAddress("mainnet.usdt"));
        super.afterInitialize();
    }

    function _testLevSwapper(uint256 shareFrom, address recipient) internal override {
        exchange.setTokens(mim, usdt);

        pushPrank(USDT_WHALE);
        uint256 amount = box.toAmount(mim, box.balanceOf(mim, address(levSwapper)), false) / 1e12;
        assertGe(usdt.balanceOf(USDT_WHALE), amount, "whale doesn't have enough usdt");
        usdt.safeTransfer(address(exchange), amount);
        popPrank();

        bytes memory data = abi.encode(usdt, 0, "123");
        levSwapper.swap(recipient, 0, shareFrom, data);
    }

    function _testSwapper(uint256 shareFrom, address recipient) internal override {
        exchange.setTokens(usdt, mim);

        pushPrank(MIM_WHALE);
        mim.transfer(address(exchange), 1e18);
        popPrank();

        bytes memory data = abi.encode(0, "123");
        swapper.swap(address(0), address(0), recipient, 0, shareFrom, data);
    }
}
