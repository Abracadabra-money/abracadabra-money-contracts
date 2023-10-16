// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import {IERC20, ERC20} from "BoringSolidity/ERC20.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {SafeApprove} from "libraries/SafeApprove.sol";
import {MagicCurveLpScript} from "script/MagicCurveLpCauldron.s.sol";
import {ProxyOracle} from "oracles/ProxyOracle.sol";
import {ICurveRewardGauge} from "interfaces/ICurveRewardGauge.sol";
import {ExchangeRouterMock} from "./mocks/ExchangeRouterMock.sol";
import {IWETHAlike} from "interfaces/IWETH.sol";
import {MagicCurveLp} from "tokens/MagicCurveLp.sol";
import {MagicCurveLpHarvestor} from "periphery/MagicCurveLpHarvestor.sol";
import {ICurvePool} from "interfaces/ICurvePool.sol";
import {MathLib} from "libraries/MathLib.sol";
import {MagicCurveLpRewardHandler, IMagicCurveLpRewardHandler, MagicCurveLpRewardHandlerDataV1} from "periphery/MagicCurveLpRewardHandler.sol";

contract MagicCurveLpRewardHandlerV2Mock is MagicCurveLpRewardHandlerDataV1 {
    uint256 public newSlot;

    function handleFunctionWithANewName(uint256 param1, ICurveRewardGauge __staking, string memory _name) external {
        newSlot = param1;
        name = _name;
        _staking = __staking;
    }
}

abstract contract MagicCurveLpTestBase is BaseTest {
    using SafeApprove for IERC20;
    using SafeApprove for ERC20;

    event LogRewardHandlerChanged(IMagicCurveLpRewardHandler indexed previous, IMagicCurveLpRewardHandler indexed current);

    MagicCurveLp vault;
    MagicCurveLpHarvestor harvestor;

    ERC20 asset;
    ICurveRewardGauge staking;
    IERC20 rewardToken;
    uint8 tokenInDecimals;
    address lpTokenInWhale;

    function initialize(uint8 _tokenInDecimals, address _lpTokenInWhale) public {
        super.setUp();
        tokenInDecimals = _tokenInDecimals;
        lpTokenInWhale = _lpTokenInWhale;
    }

    function afterInitialize() public {
        asset = ERC20(address(vault.asset()));
        staking = IMagicCurveLpRewardHandler(address(vault)).staking();

        pushPrank(harvestor.owner());
        harvestor.setOperator(harvestor.owner(), true);
        popPrank();

        pushPrank(vault.owner());
        vault.setOperator(vault.owner(), true);
        popPrank();
    }

    function testProtectedDepositAndWithdrawFunctions() public {
        // it should never be possible to call deposit and withdraw directly
        vm.expectRevert(abi.encodeWithSignature("ErrPrivateFunction()"));
        IMagicCurveLpRewardHandler(address(vault)).stakeAsset(123);

        vm.expectRevert(abi.encodeWithSignature("ErrPrivateFunction()"));
        IMagicCurveLpRewardHandler(address(vault)).unstakeAsset(123);

        // call throught fallback function from EOA
        {
            bytes memory data = abi.encodeWithSelector(MagicCurveLpRewardHandler.stakeAsset.selector, 123);
            vm.expectRevert(abi.encodeWithSignature("ErrPrivateFunction()"));
            (bool success, ) = address(vault).call{value: 0}(data);
            assertTrue(success);
        }

        {
            bytes memory data = abi.encodeWithSelector(MagicCurveLpRewardHandler.unstakeAsset.selector, 123);
            vm.expectRevert(abi.encodeWithSignature("ErrPrivateFunction()"));
            (bool success, ) = address(vault).call{value: 0}(data);
            assertTrue(success);
        }
    }

    function testUpgradeRewardHandler() internal {
        MagicCurveLpRewardHandlerV2Mock newHandler = new MagicCurveLpRewardHandlerV2Mock();
        IMagicCurveLpRewardHandler previousHandler = IMagicCurveLpRewardHandler(vault.rewardHandler());

        vm.startPrank(vault.owner());
        MagicCurveLpRewardHandler(address(vault)).harvest(address(this));

        // check random slot storage value for handler and wrapper
        ICurveRewardGauge previousValue1 = IMagicCurveLpRewardHandler(address(vault)).staking();
        string memory previousValue2 = vault.name();

        // upgrade the handler
        vm.expectEmit(true, true, true, true);
        emit LogRewardHandlerChanged(previousHandler, IMagicCurveLpRewardHandler(address(newHandler)));
        vault.setRewardHandler(IMagicCurveLpRewardHandler(address(newHandler)));

        ICurveRewardGauge _staking = IMagicCurveLpRewardHandler(address(vault)).staking();
        assertEq(address(_staking), address(previousValue1));
        assertEq(vault.name(), previousValue2);

        MagicCurveLpRewardHandlerV2Mock(address(vault)).handleFunctionWithANewName(111, ICurveRewardGauge(address(0)), "abracadabra");

        _staking = IMagicCurveLpRewardHandler(address(vault)).staking();

        assertEq(address(_staking), address(0));
        assertEq(vault.name(), "abracadabra");
        assertEq(MagicCurveLpRewardHandlerV2Mock(address(vault)).newSlot(), 111);
        vm.stopPrank();
    }

    function testTotalAssetsMatchesBalanceOf(uint256 amount1, uint256 amount2, uint256 amount3, uint256 rewards) public {
        amount1 = bound(amount1, 1, 1_000_000_000 ether);
        amount2 = bound(amount2, 1, 1_000_000_000 ether);
        amount3 = bound(amount3, 1, 1_000_000_000 ether);
        address curveLpWhale = lpTokenInWhale;

        pushPrank(curveLpWhale);
        _mintLPTokens(curveLpWhale, 30_000 * (10 ** tokenInDecimals), curveLpWhale);
        assertGt(asset.balanceOf(curveLpWhale), 0);
        popPrank();

        uint256 total = amount1 + amount2 + amount3;
        uint256 boundedTotal = bound(total, 1, asset.balanceOf(curveLpWhale) / 2);
        rewards = bound(rewards, 1, asset.balanceOf(curveLpWhale) / 4);
        amount1 = (amount1 * 1e18) / total;
        amount2 = (amount2 * 1e18) / total;
        amount3 = (amount3 * 1e18) / total;
        amount1 = (amount1 * boundedTotal) / 1e18;
        amount2 = (amount2 * boundedTotal) / 1e18;
        amount3 = (amount3 * boundedTotal) / 1e18;

        amount1 = MathLib.max(1, amount1);
        amount2 = MathLib.max(1, amount2);
        amount3 = MathLib.max(1, amount3);

        pushPrank(curveLpWhale);
        asset.transfer(alice, amount1);
        asset.transfer(bob, amount2);
        asset.transfer(carol, amount3);
        popPrank();

        pushPrank(alice);
        asset.approve(address(vault), amount1);
        uint256 share1 = vault.deposit(amount1, alice);
        _assertStakingMatchTotalAssets();
        assertEq(vault.totalAssets(), staking.balanceOf(address(vault)), "alice totalAssets should match balanceOf");
        assertEq(vault.convertToAssets(1e18), 1e18, "alice convertToAssets should match totalAssets");
        assertEq(vault.totalAssets(), vault.totalSupply(), "alice totalAssets should match totalSupply");
        popPrank();

        pushPrank(bob);
        asset.approve(address(vault), amount2);
        uint256 share2 = vault.deposit(amount2, bob);
        _assertStakingMatchTotalAssets();
        assertEq(vault.totalAssets(), staking.balanceOf(address(vault)), "bob totalAssets should match balanceOf");
        assertEq(vault.convertToAssets(1e18), 1e18, "bob convertToAssets should match totalAssets");
        assertEq(vault.totalAssets(), vault.totalSupply(), "bob totalAssets should match totalSupply");
        popPrank();

        pushPrank(carol);
        asset.approve(address(vault), amount3);
        uint256 share3 = vault.deposit(amount3, carol);
        _assertStakingMatchTotalAssets();
        assertEq(vault.totalAssets(), staking.balanceOf(address(vault)), "carol totalAssets should match balanceOf");
        assertEq(vault.convertToAssets(1e18), 1e18, "carol convertToAssets should match totalAssets");
        assertEq(vault.totalAssets(), vault.totalSupply(), "carol totalAssets should match totalSupply");
        popPrank();

        // Redeem
        pushPrank(alice);
        vault.redeem(share1, alice, alice);
        _assertStakingMatchTotalAssets();
        assertEq(vault.totalAssets(), staking.balanceOf(address(vault)), "alice totalAssets should match balanceOf when redeeming");
        assertEq(vault.convertToAssets(1e18), 1e18, "alice convertToAssets should match totalAssets when redeeming");
        assertEq(vault.totalAssets(), vault.totalSupply(), "alice totalAssets should match totalSupply when redeeming");
        popPrank();

        // simulate rewards
        pushPrank(curveLpWhale);
        uint256 previousTotalAsset = vault.totalAssets();
        asset.approve(address(vault), rewards);
        vm.expectRevert();
        IMagicCurveLpRewardHandler(address(vault)).distributeRewards(rewards);
        _assertStakingMatchTotalAssets();
        pushPrank(vault.owner());
        vault.setOperator(curveLpWhale, true);
        popPrank();

        asset.approve(address(vault), 0);
        vm.expectRevert();
        IMagicCurveLpRewardHandler(address(vault)).distributeRewards(rewards);
        _assertStakingMatchTotalAssets();
        asset.approve(address(vault), rewards);
        IMagicCurveLpRewardHandler(address(vault)).distributeRewards(rewards);
        _assertStakingMatchTotalAssets();
        assertEq(vault.totalAssets(), previousTotalAsset + rewards, "totalAssets should match balanceOf when distributing rewards");
        assertEq(vault.totalAssets(), staking.balanceOf(address(vault)), "totalAssets should match balanceOf when distributing rewards");
        assertGt(vault.totalAssets(), vault.totalSupply(), "totalAssets should be greater than totalSupply when distributing rewards");

        popPrank();

        pushPrank(bob);
        vault.redeem(share2, bob, bob);
        _assertStakingMatchTotalAssets();
        assertGt(vault.totalAssets(), vault.totalSupply(), "totalAssets should be greater than totalSupply when redeeming");
        assertGe(vault.convertToAssets(1e18), 1e18, "convertToAssets should be greater than 1e18 when redeeming");
        assertEq(vault.totalAssets(), staking.balanceOf(address(vault)), "totalAssets should match balanceOf when redeeming");
        popPrank();

        pushPrank(carol);
        vault.redeem(share3, carol, carol);
        _assertStakingMatchTotalAssets();
        assertEq(vault.totalSupply(), 0, "carol totalSupply should be 0 when redeeming");
        assertEq(vault.totalAssets(), staking.balanceOf(address(vault)), "carol totalAssets should match balanceOf when redeeming");
        assertEq(staking.balanceOf(address(vault)), 0, "carol balanceOf should be 0 when redeeming");
        assertEq(vault.convertToAssets(1e18), 1e18, "carol convertToAssets should match totalAssets when redeeming");
        popPrank();
    }

    function testStakingSkimming(uint256 amount1, uint256 amount2, uint256 amount3, uint256 rewards) public {
        amount1 = bound(amount1, 1, 1_000_000_000 ether);
        amount2 = bound(amount2, 1, 1_000_000_000 ether);
        amount3 = bound(amount3, 1, 1_000_000_000 ether);
        address curveLpWhale = lpTokenInWhale;

        pushPrank(curveLpWhale);
        _mintLPTokens(curveLpWhale, 30_000 * (10 ** tokenInDecimals), curveLpWhale);
        assertGt(asset.balanceOf(curveLpWhale), 0);
        popPrank();

        rewards = bound(rewards, 1, asset.balanceOf(curveLpWhale) / 4);

        // transfer to vault and staking contract and try skimming it since it wasn't using the normal deposit/redeem workflow
        if (rewards > 1) {
            uint256 stakedAmountBefore = staking.balanceOf(address(vault));
            uint256 assetAmountBefore = asset.balanceOf(address(vault));

            pushPrank(curveLpWhale);
            asset.approve(address(staking), type(uint256).max);
            staking.deposit(rewards / 2, address(vault), false);
            asset.transfer(address(vault), rewards / 2);

            assertEq(staking.balanceOf(address(vault)), stakedAmountBefore + rewards / 2, "staking balance should match");
            assertEq(asset.balanceOf(address(vault)), assetAmountBefore + rewards / 2, "asset balance should match");

            popPrank();

            pushPrank(vault.owner());
            uint256 previousTotalAsset = vault.totalAssets();
            assertLt(previousTotalAsset, staking.balanceOf(address(vault)), "totalAssets should be less than balanceOf when skimAssets");

            (uint256 fromStaking, uint256 fromVault) = IMagicCurveLpRewardHandler(address(vault)).skimAssets();
            assertApproxEqAbs(fromStaking + fromVault, rewards, 1, "skimAssets should return rewards");
            assertEq(vault.totalAssets(), staking.balanceOf(address(vault)), "totalAssets should match balanceOf when skimAssets");

            (fromStaking, fromVault) = IMagicCurveLpRewardHandler(address(vault)).skimAssets();
            assertEq(fromStaking + fromVault, 0, "skimAssets should return 0 when no rewards");
            assertEq(vault.totalAssets(), staking.balanceOf(address(vault)), "totalAssets should match balanceOf when skimAssets");
            assertEq(vault.totalAssets(), previousTotalAsset, "totalAssets should not change when skimAssets");
            popPrank();
        }
    }

    function _assertStakingMatchTotalAssets() private {
        assertEq(staking.balanceOf(address(vault)), vault.totalAssets(), "staked amount not match total assets");
    }

    function _generateRewards() internal {
        advanceTime(123 days);
    }

    function _mintVaultTokens(address from, uint256 amountIn, address recipient) internal returns (uint256 amount) {
        pushPrank(from);
        amount = _mintLPTokens(from, amountIn, address(from));
        asset.approve(address(vault), amount);

        uint256 amountStakedBefore = staking.balanceOf(address(vault));
        amount = vault.deposit(amount, recipient);
        uint256 amountStakedAfter = staking.balanceOf(address(vault));

        assertEq(amountStakedAfter - amountStakedBefore, amount);
        popPrank();
    }

    function _mintLPTokens(address from, uint256 amountIn, address recipient) internal virtual returns (uint256 amount);
}

contract MagicCurveLpKavaMimUsdtVaultTest is MagicCurveLpTestBase {
    using SafeApprove for IERC20;
    using BoringERC20 for IERC20;
    using SafeApprove for ERC20;

    address constant USDT_WHALE = 0x5754284f345afc66a98fbB0a0Afe71e0F007B949;
    address constant MIM_USDT_POOL_WHALE = 0x5EeDA5BDF0A647a7089329428009eCc9CB9451cc;

    MagicCurveLpScript script;
    IERC20 usdt;

    function setUp() public override {
        fork(ChainId.Kava, 6449609);

        script = new MagicCurveLpScript();
        script.setTesting(true);

        usdt = IERC20(toolkit.getAddress(ChainId.Kava, "usdt"));

        super.initialize(6 /* USDT is 6 decimals */, USDT_WHALE);
        (vault, harvestor) = script.deploy();

        rewardToken = IERC20(toolkit.getAddress(ChainId.Kava, "wKava"));
        super.afterInitialize();
    }

    function testRewardHarvesting() public {
        _mintVaultTokens(USDT_WHALE, 1_000 * (10 ** tokenInDecimals), alice);

        uint256 ratioBefore = vault.convertToAssets(1 ether);
        assertEq(ratioBefore, 1 ether);

        _generateRewards();
        pushPrank(harvestor.owner());

        ExchangeRouterMock mockRouter = new ExchangeRouterMock(ERC20(address(rewardToken)), ERC20(address(usdt)));

        pushPrank(USDT_WHALE);
        usdt.safeTransfer(address(mockRouter), 1_000 * (10 ** tokenInDecimals));
        popPrank();

        pushPrank(harvestor.owner());
        harvestor.setExchangeRouter(address(mockRouter));
        harvestor.run(0, usdt, type(uint256).max, "");
        popPrank();

        uint256 ratioAfter = vault.convertToAssets(1 ether);
        assertGt(ratioAfter, ratioBefore);

        console2.log("Ratio before:", ratioBefore);
        console2.log("Ratio after:", ratioAfter);
    }

    function _mintLPTokens(address from, uint256 amountIn, address recipient) internal override returns (uint256 amount) {
        pushPrank(from);
        uint256 balanceLpBefore = asset.balanceOf(from);
        usdt.safeApprove(address(asset), amountIn);

        uint256[2] memory amounts = [0, amountIn];
        ICurvePool(address(asset)).add_liquidity(amounts, 0);

        amount = asset.balanceOf(from) - balanceLpBefore;
        asset.transfer(recipient, amount);
        popPrank();
    }
}
