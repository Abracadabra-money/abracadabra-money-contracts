// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "interfaces/ICauldronV2.sol";
import "script/LiquidationHelper.s.sol";
import "libraries/CauldronLib.sol";
import "periphery/LiquidationHelper.sol";

contract LiquidationHelperTest is BaseTest {
    LiquidationHelper public liquidationHelper;

    address LIQUIDATOR = 0x5f0DeE98360d8200b20812e174d139A1a633EDd2;
    ICauldronV2 cauldron = ICauldronV2(0x9617b633EF905860D919b88E1d9d9a6191795341);
    ERC20 mim;

    function setUp() public override {
        forkMainnet(16989557);
        super.setUp();

        LiquidationHelperScript script = new LiquidationHelperScript();
        script.setTesting(true);
        (liquidationHelper) = script.run();

        mim = ERC20(constants.getAddress(block.chainid, "mim"));
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
            0x9617b633EF905860D919b88E1d9d9a6191795341,
            0x779b400527494C5C195680cf2D58302648481d50,
            170050380339861256959,
            3 // intentionally using the wrong cauldron version
        );
        popPrank();
    }

    function testLiquidationWithArbitraryAmount() public {
        // try to replicate some random liquidation here
        // https://etherscan.io/tx/0x834f743bfd0e544e508618fe61022dbc747c8eb68996bfbcb8f14041daf15d2c

        uint256 borrowPart = 170050380339861256959;
        address account = 0x779b400527494C5C195680cf2D58302648481d50;
        assertTrue(liquidationHelper.isLiquidatable(cauldron, 0x779b400527494C5C195680cf2D58302648481d50));

        (uint256 expectedCollateralShare, uint256 expectedMimAmount) = CauldronLib.getLiquidationCollateralAndBorrowAmount(
            cauldron,
            borrowPart
        );

        ERC20 collateral = ERC20(address(cauldron.collateral()));
        uint256 collateralBalanceBefore = collateral.balanceOf(LIQUIDATOR);
        uint256 mimBalanceBefore = mim.balanceOf(LIQUIDATOR);

        pushPrank(LIQUIDATOR);
        mim.approve(address(liquidationHelper), expectedMimAmount);
        (uint256 collateralAmount, uint256 borrowAmount) = liquidationHelper.liquidate(address(cauldron), account, borrowPart, 1);
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
    }
}
