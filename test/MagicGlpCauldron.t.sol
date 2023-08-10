// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MagicGlpCauldron.s.sol";
import "interfaces/IGmxGlpManager.sol";
import "libraries/MathLib.sol";
import "interfaces/IGmxRewardRouterV2.sol";
import "interfaces/IGmxGlpRewardRouter.sol";
import "interfaces/IGmxStakedGlp.sol";
import "interfaces/IGmxRewardDistributor.sol";
import "interfaces/IGmxRewardTracker.sol";
import "interfaces/IOracle.sol";

interface IGmxBaseToken {
    function gov() external view returns (address);

    function setInPrivateTransferMode(bool _inPrivateTransferMode) external;
}

contract MagicGlpRewardHandlerV2Mock is MagicGlpRewardHandlerDataV1 {
    uint256 public newSlot;

    function handleFunctionWithANewName(uint256 param1, IGmxRewardRouterV2 _rewardRouter, string memory _name) external {
        newSlot = param1;
        name = _name;
        rewardRouter = _rewardRouter;
    }
}

contract MagicGlpCauldronTestBase is BaseTest {
    event Distribute(uint256 amount);
    event LogRewardHandlerChanged(address indexed previous, address indexed current);
    error ReturnRewardBalance(uint256 balance);

    ProxyOracle oracle;
    ICauldronV4 cauldron;
    IBentoBoxV1 degenBox;
    MagicGlpHarvestor harvestor;
    address mimWhale;
    ERC20 mim;
    ERC20 weth;
    ERC20 gmx;
    ERC20 esGmx;
    ERC20 sGlp;
    MagicGlp vaultGlp;
    IGmxRewardRouterV2 rewardRouter;
    IGmxGlpRewardRouter glpRewardRouter;
    IGmxGlpManager manager;
    IGmxRewardDistributor rewardDistributor;
    IGmxRewardTracker fGlp;
    IGmxRewardTracker fsGlp;
    address feeCollector;
    address wethWhale;
    address gmxWhale;
    address esGmxWhale;
    address sGlpWhale;
    uint256 expectedOraclePrice;

    function _setup(uint256 _expectedOraclePrice) internal {
        vm.prank(deployer);
        vaultGlp.approve(address(degenBox), type(uint256).max);

        vm.prank(alice);
        vaultGlp.approve(address(degenBox), type(uint256).max);

        vm.prank(bob);
        vaultGlp.approve(address(degenBox), type(uint256).max);

        expectedOraclePrice = _expectedOraclePrice;
    }

    function _generateRewards(uint256 wethAmount) internal {
        vm.startPrank(wethWhale);
        weth.transfer(address(rewardDistributor), wethAmount);

        // advancing time will lower the price feedof glp, since their internal logics
        // depends on offchain updating (?). Backup the aum here and restore with mockCalls.
        uint256 aum = manager.getAum(false);
        advanceTime(180 days);
        vm.mockCall(address(manager), abi.encodeWithSelector(IGmxGlpManager.getAum.selector, false), abi.encode(aum));

        console2.log("distributor pending rewards", weth.balanceOf(address(rewardDistributor)));
        assertGt(rewardDistributor.pendingRewards(), 0);

        fGlp.updateRewards();
        fsGlp.updateRewards();

        vm.stopPrank();
    }

    function _setupBorrow(address borrower, uint256 collateralAmount) internal {
        vm.startPrank(mimWhale);
        degenBox.setMasterContractApproval(mimWhale, address(cauldron.masterContract()), true, 0, "", "");
        mim.approve(address(degenBox), type(uint256).max);
        degenBox.deposit(mim, mimWhale, mimWhale, 500_000 ether, 0);
        degenBox.deposit(mim, mimWhale, address(cauldron), 500_000 ether, 0);
        vm.stopPrank();

        uint256 amount = _mintGlpVault(collateralAmount, address(cauldron));

        uint256 expectedMimAmount;
        {
            vm.startPrank(borrower);
            cauldron.addCollateral(borrower, true, degenBox.toShare(IERC20(address(sGlp)), amount, false));

            uint256 priceFeed = cauldron.oracle().peekSpot(cauldron.oracleData());

            amount = RebaseLibrary.toElastic(degenBox.totals(cauldron.collateral()), cauldron.userCollateralShare(borrower), false);

            uint256 collateralValue = (amount * 1e18) / priceFeed;

            console2.log("priceFeed", priceFeed);
            console2.log("collateral amount", amount);
            console2.log("collateral value", collateralValue);
            console2.log("ltv", cauldron.COLLATERIZATION_RATE());

            // borrow max minus 1%
            expectedMimAmount = (collateralValue * (cauldron.COLLATERIZATION_RATE() - 1e3)) / 1e5;
        }

        console2.log("expected borrow amount", expectedMimAmount);
        assertEq(degenBox.toAmount(mim, degenBox.balanceOf(mim, borrower), false), 0);
        cauldron.borrow(borrower, expectedMimAmount);
        assertApproxEqRel(degenBox.toAmount(mim, degenBox.balanceOf(mim, borrower), false), expectedMimAmount, 1);
        console2.log("borrowed amount", degenBox.toAmount(mim, degenBox.balanceOf(mim, borrower), false));

        (uint256 ltv, , , , , ) = CauldronLib.getUserPositionInfo(cauldron, borrower);
        console2.log("initial ltv", ltv);

        vm.stopPrank();
    }

    function testOracle() public {
        vm.startPrank(sGlpWhale);
        sGlp.transfer(alice, IERC20(sGlp).balanceOf(sGlpWhale));
        vm.stopPrank();

        vm.startPrank(alice);
        sGlp.approve(address(vaultGlp), type(uint256).max);
        vaultGlp.deposit(25_000 ether, alice);
        //console2.log("price", 1e36 / oracle.peekSpot("")); // 1e18
        assertEq(1e36 / oracle.peekSpot(""), expectedOraclePrice);

        // artifically increase share by depositing should not influence the price
        sGlp.transfer(address(vaultGlp), 25_000 ether);
        //console2.log("price", 1e36 / oracle.peekSpot("")); // 1e18
        assertEq(1e36 / oracle.peekSpot(""), expectedOraclePrice);
        vm.stopPrank();
    }

    function testLiquidation() public {
        _setupBorrow(alice, 50 ether);

        uint256 priceFeed = oracle.peekSpot(cauldron.oracleData());

        // drop glp price in half to open liquidation.
        vm.mockCall(address(oracle), abi.encodeWithSelector(ProxyOracle.get.selector, ""), abi.encode(true, priceFeed * 2));
        {
            vm.startPrank(mimWhale);
            uint8[] memory actions = new uint8[](1);
            uint256[] memory values = new uint256[](1);
            bytes[] memory datas = new bytes[](1);

            address[] memory borrowers = new address[](1);
            uint256[] memory maxBorrows = new uint256[](1);

            borrowers[0] = alice;

            console2.log("alice borrow part", cauldron.userBorrowPart(alice));
            maxBorrows[0] = cauldron.userBorrowPart(alice) / 2;

            assertEq(degenBox.balanceOf(vaultGlp, mimWhale), 0);
            actions[0] = 31;
            values[0] = 0;
            datas[0] = abi.encode(borrowers, maxBorrows, mimWhale, address(0), "");
            cauldron.cook(actions, values, datas);
            vm.stopPrank();

            console2.log("alice borrow part after liquidation", cauldron.userBorrowPart(alice));
            assertGt(degenBox.balanceOf(vaultGlp, mimWhale), 0);

            console2.log("liquidator sGlp balance after liquidation", degenBox.balanceOf(vaultGlp, mimWhale));
        }
    }

    // simple tests to see if the function at least run succesfuly
    // without in-depth testing for a v1 since the reward handler can
    // be updated later on.
    function testVestingFunctions() public {
        // Unstake GMX
        {
            vm.startPrank(gmxWhale);
            gmx.transfer(address(vaultGlp), 100 ether);
            vm.stopPrank();
            vm.startPrank(vaultGlp.owner());
            vm.mockCall(address(rewardRouter), abi.encodeWithSelector(IGmxRewardRouterV2.unstakeGmx.selector, 100 ether), "");
            MagicGlpRewardHandler(address(vaultGlp)).unstakeGmx(100 ether, 100 ether, feeCollector);
            vm.clearMockedCalls();
            assertEq(gmx.balanceOf(feeCollector), 100 ether);
            vm.stopPrank();
        }

        // Unstake esGMX and start vesting
        {
            address gov = IGmxBaseToken(address(esGmx)).gov();
            vm.startPrank(gov);

            // allow transfering esGMX during the test
            IGmxBaseToken(address(esGmx)).setInPrivateTransferMode(false);

            // bypass as the deposit with the total allowed vesting amount is complex to setup
            IGmxVester(address(rewardRouter.glpVester())).setHasMaxVestableAmount(false);
            IGmxVester(address(rewardRouter.gmxVester())).setHasMaxVestableAmount(false);

            vm.stopPrank();

            vm.startPrank(esGmxWhale);
            esGmx.transfer(address(vaultGlp), 100 ether);
            vm.stopPrank();

            vm.startPrank(vaultGlp.owner());
            vm.mockCall(address(rewardRouter), abi.encodeWithSelector(IGmxRewardRouterV2.unstakeEsGmx.selector, 100 ether), "");
            MagicGlpRewardHandler(address(vaultGlp)).unstakeEsGmxAndVest(100 ether, 50 ether, 50 ether);
            vm.clearMockedCalls();
            vm.stopPrank();
        }

        // Withdraw all esGMX from vesting
        {
            vm.startPrank(esGmxWhale);
            esGmx.transfer(address(vaultGlp), 100 ether);
            vm.stopPrank();

            vm.startPrank(vaultGlp.owner());
            vm.mockCall(address(rewardRouter.glpVester()), abi.encodeWithSelector(IGmxVester.withdraw.selector), "");
            MagicGlpRewardHandler(address(vaultGlp)).withdrawFromVesting(true, true, true);
            vm.clearMockedCalls();

            assertGt(IERC20(rewardRouter.feeGmxTracker()).balanceOf(address(vaultGlp)), 0);
            vm.stopPrank();
        }

        // Claim vested GMX and stake
        {
            vm.startPrank(gmxWhale);
            gmx.transfer(address(vaultGlp), 100 ether);
            vm.stopPrank();

            vm.startPrank(vaultGlp.owner());
            MagicGlpRewardHandler(address(vaultGlp)).claimVestedGmx(true, true, true, false);
            vm.stopPrank();
        }

        // Claim vested GMX and transfer to fee collector
        {
            vm.startPrank(gmxWhale);
            gmx.transfer(address(vaultGlp), 100 ether);
            vm.stopPrank();
            vm.startPrank(vaultGlp.owner());
            MagicGlpRewardHandler(address(vaultGlp)).claimVestedGmx(true, true, false, true);
            assertEq(gmx.balanceOf(feeCollector), 200 ether);
            vm.stopPrank();
        }
    }

    function testRewardHarvesting() public {
        _setupBorrow(alice, 100 ether);
        _generateRewards(50 ether);

        vm.startPrank(vaultGlp.owner());
        assertEq(weth.balanceOf(address(vaultGlp)), 0);
        harvestor.setFeeParameters(alice, 0);

        uint256 stakedAmounts = fGlp.stakedAmounts(address(vaultGlp));
        console2.log("stakedAmounts", stakedAmounts);
        uint256 claimable = fGlp.claimable(address(vaultGlp));
        console2.log("claimable", claimable);

        uint256 previewedClaimable = harvestor.claimable();

        MagicGlpRewardHandler(address(vaultGlp)).harvest();
        uint256 wethAmount = weth.balanceOf(address(vaultGlp));

        assertEq(previewedClaimable, wethAmount);
        assertGt(wethAmount, 0);
        console2.log("weth rewards", wethAmount);

        uint256 snapshot = vm.snapshot();
        uint256 balancesGlpBefore = sGlp.balanceOf(address(vaultGlp));
        harvestor.run(0, type(uint256).max);
        uint256 amountGlptNoFee = sGlp.balanceOf(address(vaultGlp)) - balancesGlpBefore;
        assertGt(amountGlptNoFee, 0);
        vm.stopPrank();

        // 10% fee
        vm.revertTo(snapshot);
        assertEq(sGlp.balanceOf(address(vaultGlp)), balancesGlpBefore);
        vm.startPrank(harvestor.owner());
        harvestor.setFeeParameters(alice, 0);
        vm.stopPrank();

        vm.startPrank(vaultGlp.owner());
        balancesGlpBefore = sGlp.balanceOf(address(vaultGlp));
        harvestor.run(0, type(uint256).max);
        uint256 amountGlptWithFee = sGlp.balanceOf(address(vaultGlp)) - balancesGlpBefore;
        uint256 fee = (amountGlptNoFee * 0) / 10_000;
        assertEq(amountGlptWithFee, amountGlptNoFee - fee);
        assertEq(sGlp.balanceOf(alice), fee);
        vm.stopPrank();
    }

    function testUpgradeRewardHandler() public {
        MagicGlpRewardHandlerV2Mock newHandler = new MagicGlpRewardHandlerV2Mock();
        address previousHandler = vaultGlp.rewardHandler();

        vm.startPrank(vaultGlp.owner());
        MagicGlpRewardHandler(address(vaultGlp)).harvest();

        // check random slot storage value for handler and wrapper
        IGmxRewardRouterV2 previousValue1 = MagicGlpRewardHandler(address(vaultGlp)).rewardRouter();
        string memory previousValue2 = vaultGlp.name();

        // upgrade the handler
        vm.expectEmit(true, true, true, true);
        emit LogRewardHandlerChanged(previousHandler, address(newHandler));
        vaultGlp.setRewardHandler(address(newHandler));

        assertEq(address(MagicGlpRewardHandler(address(vaultGlp)).rewardRouter()), address(previousValue1));
        assertEq(vaultGlp.name(), previousValue2);

        MagicGlpRewardHandlerV2Mock(address(vaultGlp)).handleFunctionWithANewName(111, IGmxRewardRouterV2(address(0)), "abracadabra");

        assertEq(address(MagicGlpRewardHandler(address(vaultGlp)).rewardRouter()), address(0));
        assertEq(vaultGlp.name(), "abracadabra");
        assertEq(MagicGlpRewardHandlerV2Mock(address(vaultGlp)).newSlot(), 111);
        vm.stopPrank();
    }

    function testTotalAssetsMatchesBalanceOf(uint256 amount1, uint256 amount2, uint256 amount3, uint256 rewards) public {
        amount1 = bound(amount1, 1, 1_000_000_000 ether);
        amount2 = bound(amount2, 1, 1_000_000_000 ether);
        amount3 = bound(amount3, 1, 1_000_000_000 ether);

        uint256 total = amount1 + amount2 + amount3;
        uint256 boundedTotal = bound(total, 1, sGlp.balanceOf(sGlpWhale) / 2);
        rewards = bound(rewards, 1, sGlp.balanceOf(sGlpWhale) / 4);
        amount1 = (amount1 * 1e18) / total;
        amount2 = (amount2 * 1e18) / total;
        amount3 = (amount3 * 1e18) / total;
        amount1 = (amount1 * boundedTotal) / 1e18;
        amount2 = (amount2 * boundedTotal) / 1e18;
        amount3 = (amount3 * boundedTotal) / 1e18;

        amount1 = MathLib.max(1, amount1);
        amount2 = MathLib.max(1, amount2);
        amount3 = MathLib.max(1, amount3);

        pushPrank(sGlpWhale);
        sGlp.transfer(alice, amount1);
        sGlp.transfer(bob, amount2);
        sGlp.transfer(carol, amount3);
        popPrank();

        pushPrank(alice);
        sGlp.approve(address(vaultGlp), amount1);
        uint256 share1 = vaultGlp.deposit(amount1, alice);
        assertEq(vaultGlp.totalAssets(), sGlp.balanceOf(address(vaultGlp)));
        assertEq(vaultGlp.convertToAssets(1e18), 1e18);
        assertEq(vaultGlp.totalAssets(), vaultGlp.totalSupply());
        popPrank();

        pushPrank(bob);
        sGlp.approve(address(vaultGlp), amount2);
        uint256 share2 = vaultGlp.deposit(amount2, bob);
        assertEq(vaultGlp.totalAssets(), sGlp.balanceOf(address(vaultGlp)));
        assertEq(vaultGlp.convertToAssets(1e18), 1e18);
        assertEq(vaultGlp.totalAssets(), vaultGlp.totalSupply());
        popPrank();

        pushPrank(carol);
        sGlp.approve(address(vaultGlp), amount3);
        uint256 share3 = vaultGlp.deposit(amount3, carol);
        assertEq(vaultGlp.totalAssets(), sGlp.balanceOf(address(vaultGlp)));
        assertEq(vaultGlp.convertToAssets(1e18), 1e18);
        assertEq(vaultGlp.totalAssets(), vaultGlp.totalSupply());
        popPrank();

        // Redeem
        pushPrank(alice);
        vaultGlp.redeem(share1, alice, alice);
        assertEq(vaultGlp.totalAssets(), sGlp.balanceOf(address(vaultGlp)));
        assertEq(vaultGlp.convertToAssets(1e18), 1e18);
        assertEq(vaultGlp.totalAssets(), vaultGlp.totalSupply());
        popPrank();

        // simulate rewards
        pushPrank(sGlpWhale);
        uint256 previousTotalAsset = vaultGlp.totalAssets();
        sGlp.approve(address(vaultGlp), rewards);
        vm.expectRevert();
        IMagicGlpRewardHandler(address(vaultGlp)).distributeRewards(rewards);

        pushPrank(vaultGlp.owner());
        vaultGlp.setStrategyExecutor(sGlpWhale, true);
        popPrank();

        sGlp.approve(address(vaultGlp), 0);
        vm.expectRevert();
        IMagicGlpRewardHandler(address(vaultGlp)).distributeRewards(rewards);

        sGlp.approve(address(vaultGlp), rewards);
        IMagicGlpRewardHandler(address(vaultGlp)).distributeRewards(rewards);
        assertEq(vaultGlp.totalAssets(), previousTotalAsset + rewards);
        assertEq(vaultGlp.totalAssets(), sGlp.balanceOf(address(vaultGlp)));
        assertGt(vaultGlp.totalAssets(), vaultGlp.totalSupply());
        popPrank();

        pushPrank(bob);
        vaultGlp.redeem(share2, bob, bob);
        assertGt(vaultGlp.totalAssets(), vaultGlp.totalSupply());
        assertGe(vaultGlp.convertToAssets(1e18), 1e18);
        assertEq(vaultGlp.totalAssets(), sGlp.balanceOf(address(vaultGlp)));
        popPrank();

        pushPrank(carol);
        vaultGlp.redeem(share3, carol, carol);
        assertEq(vaultGlp.totalSupply(), 0);
        assertEq(vaultGlp.totalAssets(), sGlp.balanceOf(address(vaultGlp)));
        assertEq(sGlp.balanceOf(address(vaultGlp)), 0);
        assertEq(vaultGlp.convertToAssets(1e18), 1e18);
        popPrank();

        pushPrank(sGlpWhale);
        sGlp.transfer(address(vaultGlp), rewards);

        pushPrank(vaultGlp.owner());
        previousTotalAsset = vaultGlp.totalAssets();
        assertLt(vaultGlp.totalAssets(), sGlp.balanceOf(address(vaultGlp)));
        assertEq(IMagicGlpRewardHandler(address(vaultGlp)).skimAssets(), rewards);
        assertEq(vaultGlp.totalAssets(), sGlp.balanceOf(address(vaultGlp)));
        assertEq(IMagicGlpRewardHandler(address(vaultGlp)).skimAssets(), 0);
        assertEq(vaultGlp.totalAssets(), sGlp.balanceOf(address(vaultGlp)));
        assertEq(vaultGlp.totalAssets(), previousTotalAsset);
        popPrank();

        popPrank();
    }

    function _mintGlpVault(uint256 value, address recipient) internal returns (uint256) {
        vm.startPrank(deployer);
        uint256 amount = glpRewardRouter.mintAndStakeGlpETH{value: value}(0, 0);
        sGlp.approve(address(vaultGlp), amount);
        amount = vaultGlp.deposit(amount, deployer);

        // should be able to deposit without approval.
        degenBox.deposit(vaultGlp, address(deployer), recipient, amount, 0);

        // shouldn't move the allowance
        assertEq(vaultGlp.allowance(deployer, address(degenBox)), type(uint256).max);

        vm.stopPrank();

        return amount;
    }
}

contract ArbitrumMagicGlpCauldronTest is MagicGlpCauldronTestBase {
    function setUp() public override {
        fork(ChainId.Arbitrum, 55706061);
        super.setUp();

        mim = ERC20(toolkit.getAddress("arbitrum.mim"));
        mimWhale = 0x30dF229cefa463e991e29D42DB0bae2e122B2AC7;
        wethWhale = 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;
        gmxWhale = 0x6F4e8eBa4D337f874Ab57478AcC2Cb5BACdc19c9;
        esGmxWhale = 0x423f76B91dd2181d9Ef37795D6C1413c75e02c7f;
        sGlpWhale = toolkit.getAddress("arbitrum.abracadabraWrappedStakedGlp");

        MagicGlpCauldronScript script = new MagicGlpCauldronScript();
        script.setTesting(true);

        gmx = ERC20(toolkit.getAddress("arbitrum.gmx.gmx"));
        esGmx = ERC20(toolkit.getAddress("arbitrum.gmx.esGmx"));
        sGlp = ERC20(toolkit.getAddress("arbitrum.gmx.sGLP"));
        weth = ERC20(toolkit.getAddress("arbitrum.weth"));
        fGlp = IGmxRewardTracker(toolkit.getAddress("arbitrum.gmx.fGLP"));
        fsGlp = IGmxRewardTracker(toolkit.getAddress("arbitrum.gmx.fsGLP"));
        (cauldron, vaultGlp, harvestor, oracle, , , ) = script.deploy();

        degenBox = IBentoBoxV1(cauldron.bentoBox());
        vm.startPrank(degenBox.owner());
        degenBox.whitelistMasterContract(toolkit.getAddress("arbitrum.cauldronV4"), true);
        vm.stopPrank();

        rewardRouter = IGmxRewardRouterV2(toolkit.getAddress("arbitrum.gmx.rewardRouterV2"));
        glpRewardRouter = IGmxGlpRewardRouter(toolkit.getAddress("arbitrum.gmx.glpRewardRouter"));
        manager = IGmxGlpManager(toolkit.getAddress("arbitrum.gmx.glpManager"));
        rewardDistributor = IGmxRewardDistributor(toolkit.getAddress("arbitrum.gmx.fGlpWethRewardDistributor"));

        feeCollector = BoringOwnable(address(vaultGlp)).owner();
        _setup(938676046243000000 /* expected oracle price */);
    }
}

contract AvalancheMagicGlpCauldronTest is MagicGlpCauldronTestBase {
    function setUp() public override {
        fork(ChainId.Avalanche, 27451872);
        super.setUp();

        mim = ERC20(toolkit.getAddress("avalanche.mim"));
        mimWhale = 0xAE4D3a42E46399827bd094B4426e2f79Cca543CA;
        wethWhale = 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97; // wavax
        gmxWhale = 0x4aeFa39caEAdD662aE31ab0CE7c8C2c9c0a013E8;
        esGmxWhale = 0x423f76B91dd2181d9Ef37795D6C1413c75e02c7f;
        sGlpWhale = 0xFB505Aa37508B641CE4D8f066867Db3B3F66185D;

        MagicGlpCauldronScript script = new MagicGlpCauldronScript();
        script.setTesting(true);

        gmx = ERC20(toolkit.getAddress("avalanche.gmx.gmx"));
        esGmx = ERC20(toolkit.getAddress("avalanche.gmx.esGmx"));
        sGlp = ERC20(toolkit.getAddress("avalanche.gmx.sGLP"));
        weth = ERC20(toolkit.getAddress("avalanche.wavax"));
        fGlp = IGmxRewardTracker(toolkit.getAddress("avalanche.gmx.fGLP"));
        fsGlp = IGmxRewardTracker(toolkit.getAddress("avalanche.gmx.fsGLP"));
        (cauldron, vaultGlp, harvestor, oracle, , , ) = script.deploy();

        degenBox = IBentoBoxV1(cauldron.bentoBox());
        vm.startPrank(degenBox.owner());
        degenBox.whitelistMasterContract(toolkit.getAddress("avalanche.cauldronV4"), true);
        vm.stopPrank();

        rewardRouter = IGmxRewardRouterV2(toolkit.getAddress("avalanche.gmx.rewardRouterV2"));
        glpRewardRouter = IGmxGlpRewardRouter(toolkit.getAddress("avalanche.gmx.glpRewardRouter"));
        manager = IGmxGlpManager(toolkit.getAddress("avalanche.gmx.glpManager"));
        rewardDistributor = IGmxRewardDistributor(toolkit.getAddress("avalanche.gmx.fGlpWethRewardDistributor"));

        feeCollector = BoringOwnable(address(vaultGlp)).owner();
        _setup(749705171130000000 /* expectea oracle price */);
    }
}
