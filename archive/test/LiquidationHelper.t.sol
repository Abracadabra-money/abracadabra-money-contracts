// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "interfaces/ICauldronV2.sol";
import "script/LiquidationHelper.s.sol";
import "libraries/CauldronLib.sol";
import "periphery/LiquidationHelper.sol";
import "./mocks/CauldronV2Mock.sol";
import "./mocks/CauldronV4Mock.sol";

// scenario using the following liquidation tx:
// https://etherscan.io/tx/0x834f743bfd0e544e508618fe61022dbc747c8eb68996bfbcb8f14041daf15d2c
contract LiquidationHelperCauldronV2Test is BaseTest {
    LiquidationHelper public liquidationHelper;

    address LIQUIDATOR = 0x5f0DeE98360d8200b20812e174d139A1a633EDd2;
    address account = 0x779b400527494C5C195680cf2D58302648481d50;
    ICauldronV2 cauldron = ICauldronV2(0x9617b633EF905860D919b88E1d9d9a6191795341);
    ERC20 collateral;
    ERC20 mim;

    function setUp() public override {
        fork(ChainId.Mainnet, 16989557);
        super.setUp();

        LiquidationHelperScript script = new LiquidationHelperScript();
        script.setTesting(true);
        (liquidationHelper) = script.deploy();

        mim = ERC20(toolkit.getAddress("mim", block.chainid));
        collateral = ERC20(address(cauldron.collateral()));
    }

    function testNotEnoughDegenBoxMim() public {
        vm.expectRevert("ERC20: balance too low");
        liquidationHelper.liquidate(address(cauldron), 0x779b400527494C5C195680cf2D58302648481d50, 170050380339861256959, 1);
    }

    function testNoAllowanceToLiquidationHelper() public {
        pushPrank(LIQUIDATOR);
        vm.expectRevert("ERC20: allowance too low");
        liquidationHelper.liquidate(address(cauldron), 0x779b400527494C5C195680cf2D58302648481d50, 170050380339861256959, 1);
        popPrank();
    }

    function testWrongCauldronVersion() public {
        pushPrank(LIQUIDATOR);
        mim.approve(address(liquidationHelper), type(uint256).max);
        vm.expectRevert();
        liquidationHelper.liquidate(
            address(cauldron),
            account,
            170050380339861256959,
            3 // intentionally using the wrong cauldron version
        );
        popPrank();
    }

    function testLiquidationWithArbitraryAmount() public {
        uint256 borrowPart = 170050380339861256959;
        assertTrue(liquidationHelper.isLiquidatable(cauldron, 0x779b400527494C5C195680cf2D58302648481d50));

        (uint256 expectedCollateralShare, , uint256 expectedMimAmount) = CauldronLib.getLiquidationCollateralAndBorrowAmount(
            cauldron,
            account,
            borrowPart
        );

        IBentoBoxV1 box = IBentoBoxV1(cauldron.bentoBox());
        uint256 collateralBalanceBefore = collateral.balanceOf(LIQUIDATOR);
        uint256 mimBalanceBefore = mim.balanceOf(LIQUIDATOR);

        pushPrank(LIQUIDATOR);
        mim.approve(address(liquidationHelper), expectedMimAmount);
        (uint256 collateralAmount, , uint256 borrowAmount) = liquidationHelper.liquidate(address(cauldron), account, borrowPart, 1);
        popPrank();

        uint256 collateralBalanceAfter = collateral.balanceOf(LIQUIDATOR);
        uint256 mimBalanceAfter = mim.balanceOf(LIQUIDATOR);

        console2.log("expectedCollateralShare", expectedCollateralShare);
        console2.log("expectedMimAmount", expectedMimAmount);
        console2.log("collateralAmount", collateralAmount);
        console2.log("borrowAmount", borrowAmount);
        console2.log("collateralBalanceBefore", collateralBalanceBefore);
        console2.log("collateralBalanceAfter", collateralBalanceAfter);
        console2.log("mimBalanceBefore", mimBalanceBefore);
        console2.log("mimBalanceAfter", mimBalanceAfter);

        assertGe(collateralBalanceAfter, collateralBalanceBefore, "collateral balance should increase");
        assertLe(mimBalanceAfter, mimBalanceBefore, "mim balance should decrease");
        assertEq(collateralBalanceAfter - collateralBalanceBefore, expectedCollateralShare, "not enough collateral received");
        assertEq(mimBalanceBefore - mimBalanceAfter, expectedMimAmount, "not enough mim sent");
        assertEq(box.balanceOf(collateral, address(liquidationHelper)), 0, "cauldron should have no collateral left");
        assertEq(box.balanceOf(mim, address(liquidationHelper)), 0, "cauldron should have no mim left");
        assertEq(cauldron.userBorrowPart(account), 60435328810801185759, "borrow part should be reduced");
    }

    function testMaxLiquidation() public {
        IBentoBoxV1 box = IBentoBoxV1(cauldron.bentoBox());

        pushPrank(LIQUIDATOR);
        (bool liquidatable, uint256 requiredMIMAmount, uint256 borrowPart, uint256 returnedCollateralAmount) = liquidationHelper
            .previewMaxLiquidation(cauldron, account);
        uint256 collateralBalanceBefore = collateral.balanceOf(LIQUIDATOR);

        address masterContract = address(cauldron.masterContract());
        address cauldronV2Mock = address(new CauldronV2Mock(box, mim, masterContract));

        // replacing the fork implementation with the mock so it's easier to debug
        vm.etch(masterContract, cauldronV2Mock.code);

        console2.log("liquidatable", liquidatable);
        console2.log("requiredMIMAmount", requiredMIMAmount);
        console2.log("returnedCollateralAmount", returnedCollateralAmount);
        console2.log("borrowPart", borrowPart);

        assertTrue(liquidatable, "not liquidatable");
        mim.approve(address(liquidationHelper), requiredMIMAmount);
        liquidationHelper.liquidateMax(address(cauldron), account, 1);
        uint256 collateralBalanceAfter = collateral.balanceOf(LIQUIDATOR);
        popPrank();

        assertEq(box.balanceOf(collateral, address(liquidationHelper)), 0, "cauldron should have no collateral left");
        assertEq(box.balanceOf(mim, address(liquidationHelper)), 0, "cauldron should have no mim left");

        // can't be fully liquidated as the position consist of bad debt
        assertEq(cauldron.userBorrowPart(account), 60139140137105227085, "borrow part should not be 0");

        assertApproxEqAbs(cauldron.userCollateralShare(account), 0, 2, "collateral share should be approximately 0");
        assertEq(collateralBalanceAfter - collateralBalanceBefore, returnedCollateralAmount, "not enough collateral received");
    }
}

// scenario using the following liquidation tx:
// https://etherscan.io/tx/0xef95d6eeaf6d081b2a415c24ec55b8e533c9a4b310e5b93da3ac0abd34af0517
contract LiquidationHelperCauldronV4Test is BaseTest {
    LiquidationHelper public liquidationHelper;

    address LIQUIDATOR = 0x5f0DeE98360d8200b20812e174d139A1a633EDd2;
    address account = 0xa94f10D20793d54e7494D650af58EA72F0Cb5c38;
    ICauldronV2 cauldron = ICauldronV2(0x692887E8877C6Dd31593cda44c382DB5b289B684);
    ERC20 collateral;
    ERC20 mim;

    function setUp() public override {
        fork(ChainId.Mainnet, 16985039);
        super.setUp();

        LiquidationHelperScript script = new LiquidationHelperScript();
        script.setTesting(true);
        (liquidationHelper) = script.deploy();

        mim = ERC20(toolkit.getAddress("mim", block.chainid));
        collateral = ERC20(address(cauldron.collateral()));
    }

    function testWrongCauldronVersion() public {
        pushPrank(LIQUIDATOR);
        mim.approve(address(liquidationHelper), type(uint256).max);
        vm.expectRevert();
        liquidationHelper.liquidate(
            address(cauldron),
            account,
            3913399644190064211855,
            2 // intentionally using the wrong cauldron version
        );
        popPrank();
    }

    function testLiquidationWithArbitraryAmount() public {
        uint256 borrowPart = 3913399644190064211855;
        assertTrue(liquidationHelper.isLiquidatable(cauldron, 0xa94f10D20793d54e7494D650af58EA72F0Cb5c38));

        (uint256 expectedCollateralShare, , uint256 expectedMimAmount) = CauldronLib.getLiquidationCollateralAndBorrowAmount(
            cauldron,
            account,
            borrowPart
        );

        IBentoBoxV1 box = IBentoBoxV1(cauldron.bentoBox());
        uint256 collateralBalanceBefore = collateral.balanceOf(LIQUIDATOR);
        uint256 mimBalanceBefore = mim.balanceOf(LIQUIDATOR);

        pushPrank(LIQUIDATOR);
        mim.approve(address(liquidationHelper), expectedMimAmount);
        (uint256 collateralAmount, , uint256 borrowAmount) = liquidationHelper.liquidate(address(cauldron), account, borrowPart, 4);
        popPrank();

        uint256 collateralBalanceAfter = collateral.balanceOf(LIQUIDATOR);
        uint256 mimBalanceAfter = mim.balanceOf(LIQUIDATOR);

        console2.log("expectedCollateralShare", expectedCollateralShare);
        console2.log("expectedMimAmount", expectedMimAmount);
        console2.log("collateralAmount", collateralAmount);
        console2.log("borrowAmount", borrowAmount);
        console2.log("collateralBalanceBefore", collateralBalanceBefore);
        console2.log("collateralBalanceAfter", collateralBalanceAfter);
        console2.log("mimBalanceBefore", mimBalanceBefore);
        console2.log("mimBalanceAfter", mimBalanceAfter);

        assertGe(collateralBalanceAfter, collateralBalanceBefore, "collateral balance should increase");
        assertLe(mimBalanceAfter, mimBalanceBefore, "mim balance should decrease");
        assertEq(collateralBalanceAfter - collateralBalanceBefore, expectedCollateralShare, "not enough collateral received");
        assertEq(mimBalanceBefore - mimBalanceAfter, expectedMimAmount, "not enough mim sent");
        assertEq(box.balanceOf(collateral, address(liquidationHelper)), 0, "cauldron should have no collateral left");
        assertEq(box.balanceOf(mim, address(liquidationHelper)), 0, "cauldron should have no mim left");
        assertEq(cauldron.userBorrowPart(account), 0, "borrow part should be reduced");
    }

    function testMaxLiquidation() public {
        IBentoBoxV1 box = IBentoBoxV1(cauldron.bentoBox());

        {
            (, , uint256 borrowValue, uint256 collateralValue, , ) = CauldronLib.getUserPositionInfo(cauldron, account);
            console2.log("borrowPart before", cauldron.userBorrowPart(account));
            console2.log("borrowValue before", borrowValue);
            console2.log("collateralValue before", collateralValue);
        }

        pushPrank(LIQUIDATOR);
        (bool liquidatable, uint256 requiredMIMAmount, uint256 borrowPart, uint256 returnedCollateralAmount) = liquidationHelper
            .previewMaxLiquidation(cauldron, account);
        uint256 collateralBalanceBefore = collateral.balanceOf(LIQUIDATOR);

        address masterContract = address(cauldron.masterContract());
        address cauldronV4Mock = address(new CauldronV4Mock(box, mim, masterContract));
        vm.etch(masterContract, cauldronV4Mock.code);

        console2.log("liquidatable", liquidatable);
        console2.log("requiredMIMAmount", requiredMIMAmount);
        console2.log("returnedCollateralAmount", returnedCollateralAmount);
        console2.log("borrowPart", borrowPart);

        assertTrue(liquidatable, "not liquidatable");
        mim.approve(address(liquidationHelper), requiredMIMAmount);
        liquidationHelper.liquidateMax(address(cauldron), account, 4);
        uint256 collateralBalanceAfter = collateral.balanceOf(LIQUIDATOR);
        popPrank();

        {
            (, , uint256 borrowValue, uint256 collateralValue, , ) = CauldronLib.getUserPositionInfo(cauldron, account);
            console2.log("borrowPart after", cauldron.userBorrowPart(account));
            console2.log("borrowValue after", borrowValue);
            console2.log("collateralValue after", collateralValue);
        }

        assertEq(box.balanceOf(collateral, address(liquidationHelper)), 0, "cauldron should have no collateral left");
        assertEq(box.balanceOf(mim, address(liquidationHelper)), 0, "cauldron should have no mim left");

        // can't be fully liquidated as the position consist of bad debt
        assertEq(cauldron.userBorrowPart(account), 0, "borrow part should be 0");
        assertEq(cauldron.userCollateralShare(account), 231257895690562217281, "collateral share should be 0");
        assertEq(collateralBalanceAfter - collateralBalanceBefore, returnedCollateralAmount, "not enough collateral received");
    }
}
