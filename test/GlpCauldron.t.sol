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

contract GlpCauldronTest is BaseTest {
    event Distribute(uint256 amount);

    CauldronV4 masterContract;
    DegenBoxOwner degenBoxOwner;
    ICauldronV4 cauldron;
    ProxyOracle oracle;
    IBentoBoxV1 degenBox;
    MimCauldronDistributor mimDistributor;
    address mimWhale;
    ERC20 mim;
    ERC20 weth;
    IERC20 sGlp;
    GmxGlpWrapper wsGlp;
    IGmxRewardRouterV2 router;
    IGmxGlpManager manager;
    IGmxRewardDistributor rewardDistributor;
    IGmxRewardTracker fGlp;
    IGmxRewardTracker fsGlp;

    address wethWhale;

    function setUp() public override {}

    function _setupArbitrum() private {
        forkArbitrum(39407131);
        super.setUp();

        mim = ERC20(constants.getAddress("arbitrum.mim"));
        mimWhale = 0x30dF229cefa463e991e29D42DB0bae2e122B2AC7;
        wethWhale = 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;
        GlpCauldronScript script = new GlpCauldronScript();
        script.setTesting(true);
        sGlp = IERC20(constants.getAddress("arbitrum.gmx.sGLP"));
        weth = ERC20(constants.getAddress("arbitrum.weth"));
        fGlp = IGmxRewardTracker(constants.getAddress("arbitrum.gmx.fGLP"));
        fsGlp = IGmxRewardTracker(constants.getAddress("arbitrum.gmx.fsGLP"));
        (masterContract, degenBoxOwner, cauldron, oracle, wsGlp, mimDistributor) = script.run();

        router = IGmxRewardRouterV2(constants.getAddress("arbitrum.gmx.rewardRouterV2"));
        manager = IGmxGlpManager(constants.getAddress("arbitrum.gmx.glpManager"));
        rewardDistributor = IGmxRewardDistributor(constants.getAddress("arbitrum.gmx.fGlpWethRewardDistributor"));
        _setup();
    }

    function _setup() private {
        degenBox = IBentoBoxV1(cauldron.bentoBox());

        // Whitelist master contract
        vm.startPrank(degenBox.owner());
        degenBox.whitelistMasterContract(address(cauldron.masterContract()), true);
        vm.stopPrank();
    }

    function _generateRewards(uint256 wethAmount) private {
        vm.startPrank(wethWhale);
        weth.transfer(address(rewardDistributor), wethAmount);
        advanceTime(180 days);
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

            uint256 collateralValue = (amount * 1e18) / oracle.peekSpot("");

            console2.log("collateral amount", amount);
            console2.log("collateral value", collateralValue);

            uint256 ltv = cauldron.COLLATERIZATION_RATE();
            console2.log("ltv", ltv);

            // borrow max minus 1%
            expectedMimAmount = (collateralValue * (ltv - 1e3)) / 1e5;
        }

        console2.log("expected borrow amount", expectedMimAmount);
        assertEq(degenBox.toAmount(mim, degenBox.balanceOf(mim, borrower), false), 0);
        cauldron.borrow(borrower, expectedMimAmount);
        assertGe(degenBox.toAmount(mim, degenBox.balanceOf(mim, borrower), false), expectedMimAmount);
        console2.log("borrowed amount", degenBox.toAmount(mim, degenBox.balanceOf(mim, borrower), false));

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

    function testArbitrumRewardSwapping() public {
        _setupArbitrum();
        _setupBorrow(alice, 100 ether);

        _generateRewards(50 ether);

        vm.startPrank(deployer);
        assertEq(weth.balanceOf(address(wsGlp)), 0);

        uint256 stakedAmounts = fGlp.stakedAmounts(address(wsGlp));
        console2.log("stakedAmounts", stakedAmounts);
        uint256 claimable = fGlp.claimable(address(wsGlp));
        console2.log("claimable", claimable);
        GmxGlpRewardHandler(address(wsGlp)).harvest();

        uint256 wethAmount = weth.balanceOf(address(wsGlp));
        assertGt(wethAmount, 0);

        console2.log("weth rewards", wethAmount);
        GmxGlpRewardHandler(address(wsGlp)).swapRewards(0, weth, mim, address(mimDistributor), "");

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
        uint256 amount = router.mintAndStakeGlpETH{value: value}(0, 0);
        advanceTime(manager.cooldownDuration());
        sGlp.approve(address(wsGlp), amount);
        wsGlp.wrapFor(amount, address(degenBox));
        degenBox.deposit(wsGlp, address(degenBox), recipient, amount, 0);
        vm.stopPrank();

        return amount;
    }
}
