// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/GlpCauldron.s.sol";
import "periphery/MimCauldronDistributor.sol";
import "interfaces/IGmxGlpManager.sol";
import "interfaces/IGmxRewardRouterV2.sol";
import "interfaces/IGmxStakedGlp.sol";
import "interfaces/IGmxRewardDistributor.sol";
import "interfaces/IGmxRewardTracker.sol";
import "interfaces/IOracle.sol";

interface IGmxBaseToken {
    function gov() external view returns (address);

    function setInPrivateTransferMode(bool _inPrivateTransferMode) external;
}

contract GmxGlpRewardHandlerV2Mock is GmxGlpRewardHandlerDataV1 {
    uint256 public newSlot;

    function handleFunctionWithANewName(
        uint256 param1,
        uint8 _feePercent,
        string memory _name
    ) external {
        newSlot = param1;
        feePercent = _feePercent;
        name = _name;
    }
}

contract GlpCauldronTest is BaseTest {
    event Distribute(uint256 amount);
    event LogRewardHandlerChanged(address indexed previous, address indexed current);
    error ReturnRewardBalance(uint256 balance);

    CauldronV4 masterContract;
    DegenBoxOwner degenBoxOwner;
    ICauldronV4 cauldron;
    ProxyOracle oracle;
    IBentoBoxV1 degenBox;
    MimCauldronDistributor mimDistributor;
    GlpWrapperHarvestor harvestor;
    address mimWhale;
    ERC20 mim;
    ERC20 weth;
    ERC20 gmx;
    ERC20 esGmx;
    IERC20 sGlp;
    GmxGlpWrapper wsGlp;
    IGmxRewardRouterV2 rewardRouter;
    IGmxGlpManager manager;
    IGmxRewardDistributor rewardDistributor;
    IGmxRewardTracker fGlp;
    IGmxRewardTracker fsGlp;
    address feeCollector;
    address wethWhale;
    address gmxWhale;
    address esGmxWhale;

    function setUp() public override {}

    function _setupArbitrum() private {
        forkArbitrum(39407131);
        super.setUp();

        mim = ERC20(constants.getAddress("arbitrum.mim"));
        mimWhale = 0x30dF229cefa463e991e29D42DB0bae2e122B2AC7;
        wethWhale = 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;
        gmxWhale = 0x6F4e8eBa4D337f874Ab57478AcC2Cb5BACdc19c9;
        esGmxWhale = 0x423f76B91dd2181d9Ef37795D6C1413c75e02c7f;
        GlpCauldronScript script = new GlpCauldronScript();
        script.setTesting(true);

        gmx = ERC20(constants.getAddress("arbitrum.gmx.gmx"));
        esGmx = ERC20(constants.getAddress("arbitrum.gmx.esGmx"));
        sGlp = IERC20(constants.getAddress("arbitrum.gmx.sGLP"));
        weth = ERC20(constants.getAddress("arbitrum.weth"));
        fGlp = IGmxRewardTracker(constants.getAddress("arbitrum.gmx.fGLP"));
        fsGlp = IGmxRewardTracker(constants.getAddress("arbitrum.gmx.fsGLP"));
        (masterContract, degenBoxOwner, cauldron, oracle, wsGlp, mimDistributor, harvestor) = script.run();

        rewardRouter = IGmxRewardRouterV2(constants.getAddress("arbitrum.gmx.rewardRouterV2"));
        manager = IGmxGlpManager(constants.getAddress("arbitrum.gmx.glpManager"));
        rewardDistributor = IGmxRewardDistributor(constants.getAddress("arbitrum.gmx.fGlpWethRewardDistributor"));

        feeCollector = GmxGlpRewardHandler(address(wsGlp)).feeCollector();
        _setup();
    }

    function _setup() private {
        degenBox = IBentoBoxV1(cauldron.bentoBox());

        // Whitelist master contract
        vm.startPrank(degenBox.owner());
        degenBox.whitelistMasterContract(address(cauldron.masterContract()), true);
        vm.stopPrank();

        assertEq(wsGlp.allowance(deployer, address(degenBox)), type(uint256).max);
        assertEq(wsGlp.allowance(alice, address(degenBox)), type(uint256).max);
        assertEq(wsGlp.allowance(bob, address(degenBox)), type(uint256).max);
    }

    function _generateRewards(uint256 wethAmount) private {
        vm.startPrank(wethWhale);
        weth.transfer(address(rewardDistributor), wethAmount);

        // advancing time will lower the price feedof glp, since their internal logics
        // depends on offchain updating (?). Backup the aum here and restore with mockCalls.
        uint256 aum = manager.getAum(false);
        advanceTime(180 days);
        vm.mockCall(address(manager), abi.encodeWithSelector(IGmxGlpManager.getAum.selector, false), abi.encode(aum));

        console2.log("distributor pending rewards", weth.balanceOf(address(rewardDistributor)));
        assertGt(rewardDistributor.pendingRewards(), 0);

        vm.expectEmit(false, false, false, false);
        emit Distribute(0);
        fGlp.updateRewards();

        vm.expectEmit(false, false, false, false);
        emit Distribute(0);
        fsGlp.updateRewards();

        vm.stopPrank();
    }

    function _setupBorrow(address borrower, uint256 collateralAmount) public {
        vm.startPrank(mimWhale);
        degenBox.setMasterContractApproval(mimWhale, address(cauldron.masterContract()), true, 0, "", "");
        mim.approve(address(degenBox), type(uint256).max);
        degenBox.deposit(mim, mimWhale, mimWhale, 1_000_000 ether, 0);
        degenBox.deposit(mim, mimWhale, address(cauldron), 1_000_000 ether, 0);
        vm.stopPrank();

        uint256 amount = _mintGlpWrapAndWaitCooldown(collateralAmount, address(cauldron));

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
        assertGe(degenBox.toAmount(mim, degenBox.balanceOf(mim, borrower), false), expectedMimAmount);
        console2.log("borrowed amount", degenBox.toAmount(mim, degenBox.balanceOf(mim, borrower), false));

        (uint256 ltv, , ) = CauldronLib.getUserPositionInfo(cauldron, borrower);
        console2.log("initial ltv", ltv);

        vm.stopPrank();
    }

    function testArbitrumLiquidation() public {
        _setupArbitrum();
        _setupBorrow(alice, 50 ether);
        _testLiquidation();
    }

    function testArbitrumRewardHarvestinPermissions() public {
        _setupArbitrum();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSignature("ErrNotStrategyExecutor(address)", bob));
        GmxGlpRewardHandler(address(wsGlp)).swapRewards(0, IERC20(address(0)), IERC20(address(0)), address(0), "");
        vm.expectRevert(abi.encodeWithSignature("ErrNotStrategyExecutor(address)", bob));
        GmxGlpRewardHandler(address(wsGlp)).harvest();
        vm.stopPrank();

        vm.startPrank(deployer);
        vm.expectRevert(abi.encodeWithSignature("ErrUnsupportedRewardToken(address)", address(0)));
        GmxGlpRewardHandler(address(wsGlp)).swapRewards(0, IERC20(address(0)), IERC20(address(0)), address(0), "");

        vm.expectRevert(abi.encodeWithSignature("ErrUnsupportedRewardToken(address)", mim));
        GmxGlpRewardHandler(address(wsGlp)).swapRewards(0, mim, IERC20(address(0)), address(0), "");

        vm.expectRevert(abi.encodeWithSignature("ErrUnsupportedOutputToken(address)", address(0)));
        GmxGlpRewardHandler(address(wsGlp)).swapRewards(0, weth, IERC20(address(0)), address(0), "");

        vm.expectRevert(abi.encodeWithSignature("ErrRecipientNotAllowed(address)", alice));
        GmxGlpRewardHandler(address(wsGlp)).swapRewards(0, weth, mim, alice, "");
        GmxGlpRewardHandler(address(wsGlp)).swapRewards(0, weth, mim, address(mimDistributor), "");

        GmxGlpRewardHandler(address(wsGlp)).harvest();
        vm.stopPrank();
    }

    // simple tests to see if the function at least run succesfuly
    // without in-depth testing for a v1 since the reward handler can
    // be updated later on.
    function testVestingFunctions() public {
        _setupArbitrum();

        // Unstake GMX
        {
            vm.startPrank(gmxWhale);
            gmx.transfer(address(wsGlp), 100 ether);
            vm.stopPrank();
            vm.startPrank(deployer);
            vm.mockCall(address(rewardRouter), abi.encodeWithSelector(IGmxRewardRouterV2.unstakeGmx.selector, 100 ether), "");
            GmxGlpRewardHandler(address(wsGlp)).unstakeGmx(100 ether, 100 ether);
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
            esGmx.transfer(address(wsGlp), 100 ether);
            vm.stopPrank();

            vm.startPrank(deployer);
            vm.mockCall(address(rewardRouter), abi.encodeWithSelector(IGmxRewardRouterV2.unstakeEsGmx.selector, 100 ether), "");
            GmxGlpRewardHandler(address(wsGlp)).unstakeEsGmxAndVest(100 ether, 50 ether, 50 ether);
            vm.clearMockedCalls();
            vm.stopPrank();
        }

        // Withdraw all esGMX from vesting
        {
            vm.startPrank(esGmxWhale);
            esGmx.transfer(address(wsGlp), 100 ether);
            vm.stopPrank();

            vm.startPrank(deployer);
            vm.mockCall(address(rewardRouter.glpVester()), abi.encodeWithSelector(IGmxVester.withdraw.selector), "");
            GmxGlpRewardHandler(address(wsGlp)).withdrawFromVesting(true, true, true);
            vm.clearMockedCalls();

            assertGt(IERC20(rewardRouter.feeGmxTracker()).balanceOf(address(wsGlp)), 0);
            vm.stopPrank();
        }

        // Claim vested GMX and stake
        {
            vm.startPrank(gmxWhale);
            gmx.transfer(address(wsGlp), 100 ether);
            vm.stopPrank();

            vm.startPrank(deployer);
            GmxGlpRewardHandler(address(wsGlp)).claimVestedGmx(true, true, true, false);
            vm.stopPrank();
        }

        // Claim vested GMX and transfer to fee collector
        {
            vm.startPrank(gmxWhale);
            gmx.transfer(address(wsGlp), 100 ether);
            vm.stopPrank();

            vm.startPrank(deployer);
            GmxGlpRewardHandler(address(wsGlp)).claimVestedGmx(true, true, false, true);
            assertEq(gmx.balanceOf(feeCollector), 200 ether);
            vm.stopPrank();
        }

        vm.stopPrank();
    }

    function testArbitrumRewardSwappingAndDistribute() public {
        _setupArbitrum();
        _setupBorrow(alice, 100 ether);

        _generateRewards(50 ether);

        vm.startPrank(deployer);
        assertEq(weth.balanceOf(address(wsGlp)), 0);

        uint256 stakedAmounts = fGlp.stakedAmounts(address(wsGlp));
        console2.log("stakedAmounts", stakedAmounts);
        uint256 claimable = fGlp.claimable(address(wsGlp));
        console2.log("claimable", claimable);

        uint256 previewedClaimable = harvestor.claimable();

        GmxGlpRewardHandler(address(wsGlp)).harvest();
        uint256 wethAmount = weth.balanceOf(address(wsGlp));

        assertEq(previewedClaimable, wethAmount);
        assertGt(wethAmount, 0);

        console2.log("weth rewards", wethAmount);

        uint256 mimBalanceDistributor = mim.balanceOf(address(mimDistributor));
        assertEq(mim.balanceOf(address(wsGlp)), 0, "mim inside wsGlp before swapping?");

        // https://arbitrum.api.0x.org/swap/v1/quote?buyToken=0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A&sellToken=0x82aF49447D8a07e3bd95BD0d56f35241523fBab1&sellAmount=471108879012133252&slippagePercentage=1
        bytes
            memory data = hex"415565b000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000fea7a6a0b346362bf88a9e4a88416b77a57d6c2a0000000000000000000000000000000000000000000000000689b707880cf984000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003e0000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003400000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000fea7a6a0b346362bf88a9e4a88416b77a57d6c2a00000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000002c00000000000000000000000000000000000000000000000000689b707880cf984000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000002537573686953776170000000000000000000000000000000000000000000000000000000000000000689b707880cf9840000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000001b02da8cb0d097eb8d57a175b88c7d8b479975060000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000200000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000fea7a6a0b346362bf88a9e4a88416b77a57d6c2a0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000200000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000000000000000000000000000000000000000000000869584cd000000000000000000000000100000000000000000000000000000000000001100000000000000000000000000000000000000000000004f14a76c33637f93f8";
        GmxGlpRewardHandler(address(wsGlp)).swapRewards(0, weth, mim, address(mimDistributor), data);

        assertEq(weth.balanceOf(address(wsGlp)), 0, "still weth in wsGlp?");
        assertEq(mim.balanceOf(address(wsGlp)), 0, "mim inside wsGlp?");

        uint256 mimBalanceDistributorAfter = mim.balanceOf(address(mimDistributor));
        console2.log("mim in distributor", mimBalanceDistributorAfter);
        assertGt(mimBalanceDistributorAfter, mimBalanceDistributor);
        vm.stopPrank();

        (uint256 ltvBefore, , ) = CauldronLib.getUserPositionInfo(cauldron, alice);
        console2.log("alice ltv before distribution", ltvBefore);

        vm.prank(bob);
        mimDistributor.distribute();

        (uint256 ltvAfter, , ) = CauldronLib.getUserPositionInfo(cauldron, alice);
        console2.log("alice ltv after distribution", ltvAfter);

        assertLt(ltvAfter, ltvBefore, "ltv didn't lowered");
    }

    function testUpgradeRewardHandler() public {
        _setupArbitrum();

        GmxGlpRewardHandlerV2Mock newHandler = new GmxGlpRewardHandlerV2Mock();
        address previousHandler = wsGlp.rewardHandler();

        vm.startPrank(deployer);
        GmxGlpRewardHandler(address(wsGlp)).harvest();

        // check random slot storage value for handler and wrapper
        uint256 previousValue1 = GmxGlpRewardHandler(address(wsGlp)).feePercent();
        string memory previousValue2 = wsGlp.name();

        // upgrade the handler
        vm.expectEmit(true, true, true, true);
        emit LogRewardHandlerChanged(previousHandler, address(newHandler));
        wsGlp.setRewardHandler(address(newHandler));

        // function no longer exist
        vm.expectRevert();
        GmxGlpRewardHandler(address(wsGlp)).harvest();

        assertEq(GmxGlpRewardHandler(address(wsGlp)).feePercent(), previousValue1);
        assertEq(wsGlp.name(), previousValue2);

        GmxGlpRewardHandlerV2Mock(address(wsGlp)).handleFunctionWithANewName(111, 123, "abracadabra");

        assertEq(GmxGlpRewardHandler(address(wsGlp)).feePercent(), 123);
        assertEq(wsGlp.name(), "abracadabra");
        assertEq(GmxGlpRewardHandlerV2Mock(address(wsGlp)).newSlot(), 111);
        vm.stopPrank();
    }

    function _testLiquidation() private {
        uint256 priceFeed = oracle.peekSpot("");

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

            assertEq(degenBox.balanceOf(wsGlp, mimWhale), 0);
            actions[0] = 31;
            values[0] = 0;
            datas[0] = abi.encode(borrowers, maxBorrows, mimWhale, address(0), "");
            cauldron.cook(actions, values, datas);
            vm.stopPrank();

            console2.log("alice borrow part after liquidation", cauldron.userBorrowPart(alice));
            assertGt(degenBox.balanceOf(wsGlp, mimWhale), 0);

            console2.log("liquidator sGlp balance after liquidation", degenBox.balanceOf(wsGlp, mimWhale));
        }
    }

    function _mintGlpWrapAndWaitCooldown(uint256 value, address recipient) private returns (uint256) {
        vm.startPrank(deployer);
        uint256 amount = rewardRouter.mintAndStakeGlpETH{value: value}(0, 0);
        advanceTime(manager.cooldownDuration());
        sGlp.approve(address(wsGlp), amount);
        wsGlp.wrap(amount);

        // should be able to deposit without approval.
        degenBox.deposit(wsGlp, address(deployer), recipient, amount, 0);

        // shouldn't move the allowance
        assertEq(wsGlp.allowance(deployer, address(degenBox)), type(uint256).max);

        vm.stopPrank();

        return amount;
    }
}
