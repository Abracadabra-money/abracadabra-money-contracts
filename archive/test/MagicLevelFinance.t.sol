// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MagicLevelFinance.s.sol";
import "interfaces/ILevelFinanceLiquidityPool.sol";
import "interfaces/ILevelFinanceStaking.sol";
import "./mocks/ExchangeRouterMock.sol";
import {IWETHAlike} from "interfaces/IWETH.sol";

interface ILevelOracle {
    function configToken(
        address token,
        uint256 tokenDecimals,
        address priceFeed,
        uint256 priceDecimals,
        uint256 chainlinkTimeout,
        uint256 chainlinkDeviation
    ) external;

    function owner() external view returns (address);
}

contract MagicLevelRewardHandlerV2Mock is MagicLevelRewardHandlerDataV1 {
    uint256 public newSlot;

    function handleFunctionWithANewName(uint256 param1, ILevelFinanceStaking _staking, string memory _name) external {
        newSlot = param1;
        name = _name;
        staking = _staking;
    }
}

contract MagicLevelFinanceTestBase is BaseTest {
    event LogRewardHandlerChanged(IMagicLevelRewardHandler indexed previous, IMagicLevelRewardHandler indexed current);

    MagicLevelFinanceScript script;
    ProxyOracle oracle;
    MagicLevel vault;
    ILevelFinanceLiquidityPool pool;
    ERC20 llp;
    ILevelFinanceStaking staking;
    MagicLevelHarvestor harvestor;
    IERC20 rewardToken;
    uint96 pid;

    // expectations
    uint256 expectedOraclePrice;
    address constant WBNB_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
    
    function initialize(uint256 _expectedOraclePrice) public {
        fork(ChainId.BSC, 26936807);
        super.setUp();

        script = new MagicLevelFinanceScript();
        script.setTesting(true);

        expectedOraclePrice = _expectedOraclePrice;
    }

    function afterInitialize() public {
        llp = ERC20(address(vault.asset()));
        (staking, pid) = IMagicLevelRewardHandler(address(vault)).stakingInfo();
        rewardToken = IERC20(staking.rewardToken());
        pool = ILevelFinanceLiquidityPool(toolkit.getAddress("bsc.lvlfinance.liquidityPool"));
        _mockLevelOracleTimeouts(); // avoid timeout by mocking the level oracle
    }

    function testRewardHarvesting() public {
        ERC20 wbnb = ERC20(toolkit.getAddress("bsc.wbnb"));
        _mintVaultTokens(WBNB_WHALE, wbnb, 1000 ether, alice);

        uint256 ratioBefore = vault.convertToAssets(1 ether);
        assertEq(ratioBefore, 1 ether);

        _generateRewards();
        pushPrank(harvestor.owner());

        pushPrank(WBNB_WHALE);
        ExchangeRouterMock mockRouter = new ExchangeRouterMock(ERC20(address(rewardToken)), ERC20(address(wbnb)));
        wbnb.transfer(address(mockRouter), 10 ether);
        popPrank();

        pushPrank(harvestor.owner());
        harvestor.setExchangeRouter(address(mockRouter));
        harvestor.run(address(vault), 0, wbnb, type(uint256).max, "");
        popPrank();

        uint256 ratioAfter = vault.convertToAssets(1 ether);
        assertGt(ratioAfter, ratioBefore);

        console2.log("Ratio before:", ratioBefore);
        console2.log("Ratio after:", ratioAfter);
    }

    function testOracle() public {
        assertEq(oracle.peekSpot(""), expectedOraclePrice);
    }

    function testProtectedDepositAndWithdrawFunctions() public {
        // it should never be possible to call deposit and withdraw directly
        vm.expectRevert(abi.encodeWithSignature("ErrPrivateFunction()"));
        IMagicLevelRewardHandler(address(vault)).stakeAsset(123);

        vm.expectRevert(abi.encodeWithSignature("ErrPrivateFunction()"));
        IMagicLevelRewardHandler(address(vault)).unstakeAsset(123);

        // call throught fallback function from EOA
        {
            bytes memory data = abi.encodeWithSelector(MagicLevelRewardHandler.stakeAsset.selector, 123);
            vm.expectRevert(abi.encodeWithSignature("ErrPrivateFunction()"));
            (bool success, ) = address(vault).call{value: 0}(data);
            assertTrue(success);
        }

        {
            bytes memory data = abi.encodeWithSelector(MagicLevelRewardHandler.unstakeAsset.selector, 123);
            vm.expectRevert(abi.encodeWithSignature("ErrPrivateFunction()"));
            (bool success, ) = address(vault).call{value: 0}(data);
            assertTrue(success);
        }
    }

    function testUpgradeRewardHandler() internal {
        MagicLevelRewardHandlerV2Mock newHandler = new MagicLevelRewardHandlerV2Mock();
        IMagicLevelRewardHandler previousHandler = IMagicLevelRewardHandler(vault.rewardHandler());

        vm.startPrank(vault.owner());
        MagicLevelRewardHandler(address(vault)).harvest(address(this));

        // check random slot storage value for handler and wrapper
        (ILevelFinanceStaking previousValue1, ) = IMagicLevelRewardHandler(address(vault)).stakingInfo();
        string memory previousValue2 = vault.name();

        // upgrade the handler
        vm.expectEmit(true, true, true, true);
        emit LogRewardHandlerChanged(previousHandler, IMagicLevelRewardHandler(address(newHandler)));
        vault.setRewardHandler(IMagicLevelRewardHandler(address(newHandler)));

        (ILevelFinanceStaking _staking, ) = IMagicLevelRewardHandler(address(vault)).stakingInfo();
        assertEq(address(_staking), address(previousValue1));
        assertEq(vault.name(), previousValue2);

        MagicLevelRewardHandlerV2Mock(address(vault)).handleFunctionWithANewName(111, ILevelFinanceStaking(address(0)), "abracadabra");

        (_staking, ) = IMagicLevelRewardHandler(address(vault)).stakingInfo();

        assertEq(address(_staking), address(0));
        assertEq(vault.name(), "abracadabra");
        assertEq(MagicLevelRewardHandlerV2Mock(address(vault)).newSlot(), 111);
        vm.stopPrank();
    }

    function testTotalAssetsMatchesBalanceOf(uint256 amount1, uint256 amount2, uint256 amount3, uint256 rewards) public {
        amount1 = bound(amount1, 1, 1_000_000_000 ether);
        amount2 = bound(amount2, 1, 1_000_000_000 ether);
        amount3 = bound(amount3, 1, 1_000_000_000 ether);
        address llpWhale = createUser("llpWhale", address(0x4), 1_000_000_000 ether);

        pushPrank(llpWhale);
        IWETHAlike wbnb = IWETHAlike(toolkit.getAddress("bsc.wbnb"));
        wbnb.deposit{value: 30_000 ether}();
        _mintLPTokens(llpWhale, wbnb, 30_000 ether, llpWhale);
        assertGt(llp.balanceOf(llpWhale), 0);
        popPrank();

        uint256 total = amount1 + amount2 + amount3;
        uint256 boundedTotal = bound(total, 1, llp.balanceOf(llpWhale) / 2);
        rewards = bound(rewards, 1, llp.balanceOf(llpWhale) / 4);
        amount1 = (amount1 * 1e18) / total;
        amount2 = (amount2 * 1e18) / total;
        amount3 = (amount3 * 1e18) / total;
        amount1 = (amount1 * boundedTotal) / 1e18;
        amount2 = (amount2 * boundedTotal) / 1e18;
        amount3 = (amount3 * boundedTotal) / 1e18;

        amount1 = MathLib.max(1, amount1);
        amount2 = MathLib.max(1, amount2);
        amount3 = MathLib.max(1, amount3);

        pushPrank(llpWhale);
        llp.transfer(alice, amount1);
        llp.transfer(bob, amount2);
        llp.transfer(carol, amount3);
        popPrank();

        pushPrank(alice);
        llp.approve(address(vault), amount1);
        uint256 share1 = vault.deposit(amount1, alice);
        _assertStakingMatchTotalAssets();
        assertEq(vault.totalAssets(), _getLpStakingVaultBalance(), "alice totalAssets should match balanceOf");
        assertEq(vault.convertToAssets(1e18), 1e18, "alice convertToAssets should match totalAssets");
        assertEq(vault.totalAssets(), vault.totalSupply(), "alice totalAssets should match totalSupply");
        popPrank();

        pushPrank(bob);
        llp.approve(address(vault), amount2);
        uint256 share2 = vault.deposit(amount2, bob);
        _assertStakingMatchTotalAssets();
        assertEq(vault.totalAssets(), _getLpStakingVaultBalance(), "bob totalAssets should match balanceOf");
        assertEq(vault.convertToAssets(1e18), 1e18, "bob convertToAssets should match totalAssets");
        assertEq(vault.totalAssets(), vault.totalSupply(), "bob totalAssets should match totalSupply");
        popPrank();

        pushPrank(carol);
        llp.approve(address(vault), amount3);
        uint256 share3 = vault.deposit(amount3, carol);
        _assertStakingMatchTotalAssets();
        assertEq(vault.totalAssets(), _getLpStakingVaultBalance(), "carol totalAssets should match balanceOf");
        assertEq(vault.convertToAssets(1e18), 1e18, "carol convertToAssets should match totalAssets");
        assertEq(vault.totalAssets(), vault.totalSupply(), "carol totalAssets should match totalSupply");
        popPrank();

        // Redeem
        pushPrank(alice);
        vault.redeem(share1, alice, alice);
        _assertStakingMatchTotalAssets();
        assertEq(vault.totalAssets(), _getLpStakingVaultBalance(), "alice totalAssets should match balanceOf when redeeming");
        assertEq(vault.convertToAssets(1e18), 1e18, "alice convertToAssets should match totalAssets when redeeming");
        assertEq(vault.totalAssets(), vault.totalSupply(), "alice totalAssets should match totalSupply when redeeming");
        popPrank();

        // simulate rewards
        pushPrank(llpWhale);
        uint256 previousTotalAsset = vault.totalAssets();
        llp.approve(address(vault), rewards);
        vm.expectRevert();
        IMagicLevelRewardHandler(address(vault)).distributeRewards(rewards);
        _assertStakingMatchTotalAssets();
        pushPrank(vault.owner());
        vault.setOperator(llpWhale, true);
        popPrank();

        llp.approve(address(vault), 0);
        vm.expectRevert();
        IMagicLevelRewardHandler(address(vault)).distributeRewards(rewards);
        _assertStakingMatchTotalAssets();
        llp.approve(address(vault), rewards);
        IMagicLevelRewardHandler(address(vault)).distributeRewards(rewards);
        _assertStakingMatchTotalAssets();
        assertEq(vault.totalAssets(), previousTotalAsset + rewards, "totalAssets should match balanceOf when distributing rewards");
        assertEq(vault.totalAssets(), _getLpStakingVaultBalance(), "totalAssets should match balanceOf when distributing rewards");
        assertGt(vault.totalAssets(), vault.totalSupply(), "totalAssets should be greater than totalSupply when distributing rewards");

        popPrank();

        pushPrank(bob);
        vault.redeem(share2, bob, bob);
        _assertStakingMatchTotalAssets();
        assertGt(vault.totalAssets(), vault.totalSupply(), "totalAssets should be greater than totalSupply when redeeming");
        assertGe(vault.convertToAssets(1e18), 1e18, "convertToAssets should be greater than 1e18 when redeeming");
        assertEq(vault.totalAssets(), _getLpStakingVaultBalance(), "totalAssets should match balanceOf when redeeming");
        popPrank();

        pushPrank(carol);
        vault.redeem(share3, carol, carol);
        _assertStakingMatchTotalAssets();
        assertEq(vault.totalSupply(), 0, "carol totalSupply should be 0 when redeeming");
        assertEq(vault.totalAssets(), _getLpStakingVaultBalance(), "carol totalAssets should match balanceOf when redeeming");
        assertEq(_getLpStakingVaultBalance(), 0, "carol balanceOf should be 0 when redeeming");
        assertEq(vault.convertToAssets(1e18), 1e18, "carol convertToAssets should match totalAssets when redeeming");
        popPrank();

        // transfer to vault and staking contract and try skimming it since it wasn't using the normal deposit/redeem workflow
        if (rewards > 1) {
            pushPrank(llpWhale);
            llp.approve(address(staking), type(uint256).max);
            staking.deposit(pid, rewards / 2, address(vault));
            llp.transfer(address(vault), rewards / 2);
            popPrank();

            pushPrank(vault.owner());
            previousTotalAsset = vault.totalAssets();
            assertLt(previousTotalAsset, _getLpStakingVaultBalance(), "totalAssets should be less than balanceOf when skimAssets");

            (uint256 fromStaking, uint256 fromVault) = IMagicLevelRewardHandler(address(vault)).skimAssets();
            assertApproxEqAbs(fromStaking + fromVault, rewards, 1, "skimAssets should return rewards");
            assertEq(vault.totalAssets(), _getLpStakingVaultBalance(), "totalAssets should match balanceOf when skimAssets");

            (fromStaking, fromVault) = IMagicLevelRewardHandler(address(vault)).skimAssets();
            assertEq(fromStaking + fromVault, 0, "skimAssets should return 0 when no rewards");
            assertEq(vault.totalAssets(), _getLpStakingVaultBalance(), "totalAssets should match balanceOf when skimAssets");
            assertEq(vault.totalAssets(), previousTotalAsset, "totalAssets should not change when skimAssets");
            popPrank();
        }
    }

    function _assertStakingMatchTotalAssets() private {
        assertEq(_getLpStakingVaultBalance(), vault.totalAssets(), "staked amount not match total assets");
    }

    function _getLpStakingVaultBalance() internal view returns (uint256 stakedAmount) {
        (stakedAmount, ) = staking.userInfo(pid, address(vault));
    }

    function _generateRewards() internal {
        advanceTime(123 days);
    }

    function _mintLPTokens(address from, IERC20 tokenIn, uint256 amountIn, address recipient) internal returns (uint256 amount) {
        pushPrank(from);
        uint256 balanceLpBefore = llp.balanceOf(from);
        tokenIn.approve(address(pool), amountIn);
        pool.addLiquidity(address(llp), address(tokenIn), amountIn, 0, from);
        amount = llp.balanceOf(from) - balanceLpBefore;
        llp.transfer(recipient, amount);
        popPrank();
    }

    function _mintVaultTokens(address from, IERC20 tokenIn, uint256 amountIn, address recipient) internal returns (uint256 amount) {
        pushPrank(from);
        amount = _mintLPTokens(from, tokenIn, amountIn, address(from));
        llp.approve(address(vault), amount);

        (uint256 amountStakedBefore, ) = staking.userInfo(pid, address(vault));
        amount = vault.deposit(amount, recipient);
        (uint256 amountStakedAfter, ) = staking.userInfo(pid, address(vault));

        assertEq(amountStakedAfter - amountStakedBefore, amount);
        popPrank();
    }

    function _mockLevelOracleTimeouts() internal {
        ILevelOracle _oracle = ILevelOracle(toolkit.getAddress("bsc.lvlfinance.oracle"));
        uint256 timeout = block.timestamp + 365 days;

        pushPrank(_oracle.owner());
        _oracle.configToken(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c, 18, 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE, 8, timeout, 500);
        _oracle.configToken(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, 18, 0xcBb98864Ef56E9042e7d2efef76141f15731B82f, 8, timeout, 5000);
        _oracle.configToken(0x55d398326f99059fF775485246999027B3197955, 18, 0xB97Ad0E74fa7d920791E90258A6E2085088b4320, 8, timeout, 1200);
        _oracle.configToken(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82, 18, 0xB6064eD41d4f67e353768aA239cA86f4F73665a1, 8, timeout, 2000);
        _oracle.configToken(0x2170Ed0880ac9A755fd29B2688956BD959F933F8, 18, 0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e, 8, timeout, 1000);
        _oracle.configToken(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c, 18, 0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf, 8, timeout, 1000);
        popPrank();
    }
}

contract MagicLevelFinanceJuniorVaultTest is MagicLevelFinanceTestBase {
    function setUp() public override {
        super.initialize(921051199533511162 /* expected oracle price */);
        (oracle, , , vault, , , harvestor) = script.deploy();
        super.afterInitialize();
    }
}

contract MagicLevelFinanceMezzanineVaultTest is MagicLevelFinanceTestBase {
    function setUp() public override {
        super.initialize(971790522869011181 /* expected oracle price */);
        (, oracle, , , vault, , harvestor) = script.deploy();
        super.afterInitialize();
    }
}

contract MagicLevelFinanceSeniorVaultTest is MagicLevelFinanceTestBase {
    function setUp() public override {
        super.initialize(809214587157509035 /* expected oracle price */);
        (, , oracle, , , vault, harvestor) = script.deploy();
        super.afterInitialize();
    }
}
