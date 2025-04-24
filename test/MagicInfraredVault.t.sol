// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MagicInfraredVault.s.sol";
import {MagicInfraredVault} from "/tokens/MagicInfraredVault.sol";
import {MagicInfraredVaultHarvester} from "/harvesters/MagicInfraredVaultHarvester.sol";
import {IInfraredStaking} from "/interfaces/IInfraredStaking.sol";
import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import {IKodiakVaultV1} from "/interfaces/IKodiak.sol";
import {ExchangeRouterMock} from "test/mocks/ExchangeRouterMock.sol";
import {MagicInfraredVaultSwapper} from "/swappers/MagicInfraredVaultSwapper.sol";
import {MagicInfraredVaultLevSwapper} from "/swappers/MagicInfraredVaultLevSwapper.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {IKodiakV1RouterStaking} from "/interfaces/IKodiak.sol";

contract MagicInfraredVaultV2 is MagicInfraredVault {
    address public foo;

    constructor(address __asset) MagicInfraredVault(__asset) {}

    function failingInitialize(address _owner) public reinitializer(1) {
        _initializeOwner(_owner);
    }

    function initializeV2(address _owner, address _foo) public reinitializer(2) {
        _initializeOwner(_owner);
        foo = _foo;
    }
}

contract MagicInfraredVaultTestBase is BaseTest {
    IBentoBoxLite box;
    address mim;
    MagicInfraredVault[] vaults;
    ICauldronV4[] cauldrons;
    MagicInfraredVaultHarvester[] harvesters;
    ISwapperV2[] swappers;
    ILevSwapperV2[] levSwappers;

    MagicInfraredVault vault;
    ICauldronV4 cauldron;
    MagicInfraredVaultHarvester harvester;
    ISwapperV2 swapper;
    ILevSwapperV2 levSwapper;

    address asset;
    address token0;
    address token1;
    address user;
    address rewardToken;

    uint256 constant INITIAL_DEPOSIT = 100e18;
    address constant REWARDS_RECIPIENT = address(0xBEEF);

    function setUp() public virtual override {
        fork(ChainId.Bera, 4138788);
        super.setUp();

        MagicInfraredVaultScript script = new MagicInfraredVaultScript();
        script.setTesting(true);

        (vaults, cauldrons, harvesters, swappers, levSwappers) = script.deploy();
        user = makeAddr("user");
        vm.deal(user, 100 ether);

        box = IBentoBoxLite(toolkit.getAddress("degenBox"));
        mim = toolkit.getAddress("mim");
    }

    function initialize(uint256 index) public {
        vault = vaults[index];
        cauldron = cauldrons[index];
        harvester = harvesters[index];
        swapper = swappers[index];
        levSwapper = levSwappers[index];
        asset = vault.asset();
        token0 = IKodiakVaultV1(asset).token0();
        token1 = IKodiakVaultV1(asset).token1();

        // Set up reward token - assuming first reward token from staking
        IInfraredStaking staking = vault.staking();
        address[] memory rewardTokens = staking.getAllRewardTokens();
        if (rewardTokens.length > 0) {
            rewardToken = rewardTokens[0];
        } else {
            rewardToken = makeAddr("rewardToken");
        }
    }

    function testStorage() public view {
        assertNotEq(vault.asset(), address(0), "the asset should not be the zero address");
        assertNotEq(vault.owner(), address(0), "the owner should not be the zero address");
        assertNotEq(address(vault.staking()), address(0), "staking should not be the zero address");
    }

    function testUpgrade() public {
        address randomAsset = makeAddr("asset");
        MagicInfraredVaultV2 newImpl = new MagicInfraredVaultV2(randomAsset);

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        vault.initialize(alice);

        pushPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        vault.upgradeToAndCall(address(newImpl), "");
        popPrank();

        address owner = vault.owner();
        pushPrank(owner);
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        vault.upgradeToAndCall(address(newImpl), abi.encodeCall(newImpl.failingInitialize, (owner)));

        address randomAddr = makeAddr("addr");

        vault.upgradeToAndCall(address(newImpl), abi.encodeCall(newImpl.initializeV2, (owner, randomAddr)));
        assertEq(vault.owner(), owner, "owner should be the same");
        assertEq(MagicInfraredVaultV2(address(vault)).foo(), randomAddr, "foo should be set");
        assertEq(vault.asset(), randomAsset, "asset should be updated");
        popPrank();

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        MagicInfraredVaultV2(address(vault)).initializeV2(alice, alice);
    }

    function testHarvestSimple() public {
        address owner = vault.owner();
        pushPrank(owner);
        vault.harvest(tx.origin);
        popPrank();
    }

    // New tests

    function testDepositAndWithdraw() public {
        uint256 depositAmount = 10e18;

        // Setup - mint some assets to the user
        deal(asset, user, depositAmount);

        // Check initial state
        assertEq(IERC20(asset).balanceOf(user), depositAmount, "User should have assets");
        assertEq(IERC20(asset).balanceOf(address(vault)), 0, "Vault should have no assets initially");
        assertEq(vault.totalAssets(), 0, "Vault total assets should be 0");

        // Approve and deposit
        pushPrank(user);
        IERC20(asset).approve(address(vault), depositAmount);
        uint256 mintedShares = vault.deposit(depositAmount, user);
        popPrank();

        // Check post-deposit state
        assertEq(IERC20(asset).balanceOf(user), 0, "User should have no assets left");
        assertGt(mintedShares, 0, "Should have minted shares");
        assertEq(vault.balanceOf(user), mintedShares, "User should have shares");
        assertEq(vault.totalSupply(), mintedShares, "Total supply should match shares");
        assertEq(vault.totalAssets(), depositAmount, "Vault total assets should match deposit");

        // Check staking integration - asset should be staked
        IInfraredStaking staking = vault.staking();
        uint256 stakedBalance = staking.balanceOf(address(vault));
        assertEq(stakedBalance, depositAmount, "Asset should be staked with InfraredStaking");

        // Withdraw half
        uint256 withdrawAmount = depositAmount / 2;
        pushPrank(user);
        uint256 sharesRedeemed = vault.withdraw(withdrawAmount, user, user);
        popPrank();

        // Check post-withdraw state
        assertGt(sharesRedeemed, 0, "Should have redeemed shares");
        assertEq(IERC20(asset).balanceOf(user), withdrawAmount, "User should have withdrawn assets");
        assertEq(vault.balanceOf(user), mintedShares - sharesRedeemed, "User should have remaining shares");
        assertEq(vault.totalAssets(), depositAmount - withdrawAmount, "Vault total assets should be reduced");

        // Check staking integration - less asset should be staked
        stakedBalance = staking.balanceOf(address(vault));
        assertEq(stakedBalance, depositAmount - withdrawAmount, "Less asset should be staked");
    }

    function testRewardsHarvesting() public {
        uint256 depositAmount = 100e18;

        // Setup - mint some assets and deposit
        deal(asset, user, depositAmount);
        pushPrank(user);
        IERC20(asset).approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user);
        popPrank();

        advanceTime(1 weeks);

        // Verify rewards can be harvested
        pushPrank(vault.owner());
        uint256 vaultBalanceBefore = IERC20(asset).balanceOf(address(vault));
        vault.harvest(REWARDS_RECIPIENT);

        // Check rewards were sent to the recipient
        assertGt(IERC20(rewardToken).balanceOf(REWARDS_RECIPIENT), 0, "Rewards should be sent to recipient");
        assertEq(IERC20(asset).balanceOf(address(vault)), vaultBalanceBefore, "Vault asset balance shouldn't change from harvest");
        popPrank();
    }

    function testDistributeRewards() public {
        uint256 depositAmount = 100e18;
        uint256 rewardAmount = 10e18;

        // Setup - mint some assets and deposit
        deal(asset, user, depositAmount);
        pushPrank(user);
        IERC20(asset).approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user);
        popPrank();

        // Initial vault state
        uint256 initialTotalAssets = vault.totalAssets();

        // Mint rewards to an operator
        address operator = vault.owner();
        deal(asset, operator, rewardAmount);

        // Distribute rewards
        pushPrank(operator);
        IERC20(asset).approve(address(vault), rewardAmount);
        vault.distributeRewards(rewardAmount);
        popPrank();

        // Check that total assets increased
        uint256 finalTotalAssets = vault.totalAssets();
        assertEq(finalTotalAssets, initialTotalAssets + rewardAmount, "Total assets should increase by reward amount");

        // Check that the rewards were staked
        IInfraredStaking staking = vault.staking();
        uint256 stakedBalance = staking.balanceOf(address(vault));
        assertEq(stakedBalance, depositAmount + rewardAmount, "Total staked amount should include rewards");
    }

    function testHarvesterIntegration() public {
        // Skip if harvester wasn't found
        if (address(harvester) == address(0)) return;

        uint256 depositAmount = 100e18;

        // Setup - mint some assets and deposit
        deal(asset, user, depositAmount);
        pushPrank(user);
        IERC20(asset).approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user);
        popPrank();

        // Create mock exchange and fund it with tokens
        ExchangeRouterMock mockExchange = new ExchangeRouterMock(address(0), address(0));

        // Fund the mock exchange and staking contract with reward tokens
        deal(rewardToken, address(vault.staking()), 50e18);
        deal(rewardToken, address(mockExchange), 50e18, true);

        // Fund mock exchange with the tokens it will return from swaps
        deal(token0, address(mockExchange), 5e18, true);
        deal(token1, address(mockExchange), 5e18, true);
        deal(asset, address(mockExchange), 20e18, true);

        // Configure harvester to use mock exchange
        address operator = harvester.owner();
        pushPrank(operator);
        harvester.setExchangeRouter(address(mockExchange));

        // Create swap calls with specific tokens
        bytes[] memory swaps = new bytes[](2);
        swaps[0] = abi.encodeCall(mockExchange.swapArbitraryTokens, (rewardToken, token0, address(harvester)));
        swaps[1] = abi.encodeCall(mockExchange.swapArbitraryTokens, (rewardToken, token1, address(harvester)));

        uint256 initialTotalAssets = vault.totalAssets();

        // Before the swap operation, mock the staking withdraw function
        address stakingAddress = address(vault.staking());
        vm.mockCall(stakingAddress, abi.encodeWithSignature("withdraw(uint256)", depositAmount), abi.encode());

        // Also make sure the asset is available in the vault for withdrawal
        deal(asset, address(vault), depositAmount);

        // Run harvester with a minimum LP out of 0 to prevent the below min amounts error
        harvester.run(swaps, 5e18, 5e18, 1);

        // Check that total assets increased
        uint256 finalTotalAssets = vault.totalAssets();
        assertGt(finalTotalAssets, initialTotalAssets, "Total assets should increase after harvester run");

        // Check fee collection
        address feeCollector = harvester.feeCollector();
        assertGt(IERC20(asset).balanceOf(feeCollector), 0, "Fee collector should have received assets");

        popPrank();
    }

    function testVaultValueIncreases() public {
        uint256 depositAmount = 100e18;
        uint256 rewardAmount = 10e18;

        // Setup - mint some assets and deposit
        deal(asset, user, depositAmount);
        pushPrank(user);
        IERC20(asset).approve(address(vault), depositAmount);
        uint256 sharesMinted = vault.deposit(depositAmount, user);
        popPrank();

        // Record initial share price
        uint256 initialSharePrice = (vault.totalAssets() * 1e18) / vault.totalSupply();

        // Simulate yield accumulation by distributing rewards
        address operator = vault.owner();
        deal(asset, operator, rewardAmount);

        pushPrank(operator);
        IERC20(asset).approve(address(vault), rewardAmount);
        vault.distributeRewards(rewardAmount);
        popPrank();

        // Calculate new share price
        uint256 newSharePrice = (vault.totalAssets() * 1e18) / vault.totalSupply();

        // Share price should have increased
        assertGt(newSharePrice, initialSharePrice, "Share price should increase after rewards");

        // Original depositor should get more assets for their shares
        uint256 assetsForShares = vault.convertToAssets(sharesMinted);
        assertGt(assetsForShares, depositAmount, "Assets redeemable for initial shares should increase");

        // When withdrawing all shares, user should get initial deposit plus a portion of rewards
        pushPrank(user);
        uint256 withdrawnAssets = vault.redeem(sharesMinted, user, user);
        popPrank();

        assertGt(withdrawnAssets, depositAmount, "User should withdraw more than they deposited");
        assertEq(withdrawnAssets, assetsForShares, "Withdrawn assets should match calculated assets for shares");
    }

    function testOnlyOwnerCanSetStaking() public {
        address newStaking = makeAddr("newStaking");

        pushPrank(alice);
        vm.expectRevert(); // Should revert as alice is not the owner
        vault.setStaking(IInfraredStaking(newStaking));
        popPrank();

        pushPrank(vault.owner());
        vault.setStaking(IInfraredStaking(newStaking));
        assertEq(address(vault.staking()), newStaking, "Staking should be updated");
        popPrank();
    }

    function testOperatorPermissions() public {
        address operator = makeAddr("operator");
        address nonOperator = makeAddr("nonOperator");
        uint256 rewardAmount = 10e18;

        // Set operator
        pushPrank(vault.owner());
        vault.setOperator(operator, true);
        popPrank();

        // Mint rewards
        deal(asset, operator, rewardAmount);
        deal(asset, nonOperator, rewardAmount);

        // Non-operator cannot distribute rewards
        pushPrank(nonOperator);
        IERC20(asset).approve(address(vault), rewardAmount);
        vm.expectRevert(); // Should revert as non-operator cannot distribute
        vault.distributeRewards(rewardAmount);
        popPrank();

        // Operator can distribute rewards
        pushPrank(operator);
        IERC20(asset).approve(address(vault), rewardAmount);
        vault.distributeRewards(rewardAmount);
        popPrank();
    }

    function testSwapperIntegration() public {
        uint256 depositAmount = 10e18;
        deal(asset, user, depositAmount, true);
        pushPrank(user);
        IERC20(asset).approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user);

        ExchangeRouterMock mockExchange = new ExchangeRouterMock(address(0), address(0));
        uint256 userMimBalanceBefore = box.balanceOf(mim, user);
        deal(mim, user, 20 ether);

        vault.transfer(address(box), depositAmount);
        (uint256 depositShare, ) = box.deposit(address(vault), address(box), address(swapper), depositAmount, 0);

        // verify the box has the correct balance of the vault
        assertEq(box.balanceOf(address(vault), address(swapper)), depositAmount);

        // Prepare swap data
        address[] memory to = new address[](2);
        to[0] = address(mockExchange);
        to[1] = address(mockExchange);

        // deal mim to mock
        deal(mim, address(mockExchange), 20 ether, true);

        bytes[] memory swapData = new bytes[](2);
        swapData[0] = abi.encodeCall(mockExchange.swapArbitraryTokensExactAmountOut, (token0, mim, 10 ether, address(swapper)));
        swapData[1] = abi.encodeCall(mockExchange.swapArbitraryTokensExactAmountOut, (token1, mim, 10 ether, address(swapper)));

        bytes memory data = abi.encode(to, swapData);
        uint256 minShareOut = box.toShare(mim, 20 ether, false);
        swapper.swap(address(0), address(0), user, minShareOut, depositShare, data);

        // Verify MIM received
        uint256 userMimBalanceAfter = box.balanceOf(mim, user);
        assertGt(userMimBalanceAfter, userMimBalanceBefore, "User should have received MIM");

        popPrank();
    }

    function testLevSwapperIntegration() public {
        uint256 mimAmount = 100e18;
        deal(mim, user, mimAmount);

        // Deposit MIM into BentoBox
        pushPrank(user);
        IERC20(mim).approve(address(box), mimAmount);
        box.deposit(mim, user, address(levSwapper), mimAmount, 0);

        // Create mock exchange and fund it
        ExchangeRouterMock mockExchange = new ExchangeRouterMock(address(0), address(0));
        deal(token0, address(mockExchange), 50e18, true);
        deal(token1, address(mockExchange), 50e18, true);

        // Prepare swap data
        address[] memory to = new address[](2);
        to[0] = address(mockExchange);
        to[1] = address(mockExchange);

        bytes[] memory swapData = new bytes[](2);
        swapData[0] = abi.encodeCall(mockExchange.swapArbitraryTokens, (mim, token0, address(levSwapper)));
        swapData[1] = abi.encodeCall(mockExchange.swapArbitraryTokens, (mim, token1, address(levSwapper)));

        bytes memory data = abi.encode(to, swapData);

        uint256 shareAmount = box.toShare(mim, mimAmount, false);

        // Execute lev swap
        levSwapper.swap(user, 0, shareAmount, data);

        // Verify vault shares received
        assertGt(box.balanceOf(address(vault), user), 0, "User should have received vault shares");

        popPrank();
    }
}

contract MagicInfrared_WBERA_HONEY_Test is MagicInfraredVaultTestBase {
    function setUp() public virtual override {
        super.setUp();
        initialize(0);
    }
}

contract MagicInfrared_WETH_WBERA_Test is MagicInfraredVaultTestBase {
    function setUp() public virtual override {
        super.setUp();
        initialize(1);
    }
}

contract MagicInfrared_WBTC_WBERA_Test is MagicInfraredVaultTestBase {
    function setUp() public virtual override {
        super.setUp();
        initialize(2);
    }
}
