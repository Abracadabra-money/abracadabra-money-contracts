// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/ERC20.sol";
import "utils/BaseTest.sol";
import "script/SpookySwapStrategyV2.s.sol";

contract SpookySwapStrategyV2Test is BaseTest {
    IMasterChef constant farmV1 = IMasterChef(0x2b2929E785374c651a81A63878Ab22742656DcDd);
    address constant wftmmimStrategyV1 = 0x184a07c9CFD6165D6ACCDc373Eb00Bc5Cd8733cF;

    event LpMinted(uint256 total, uint256 strategyAmount, uint256 feeAmount);
    event LogStrategyProfit(address indexed token, uint256 amount);
    event LogStrategyDivest(address indexed token, uint256 amount);
    event LogStrategyQueued(address indexed token, address indexed strategy);

    IBentoBoxV1 degenBox;
    SpookySwapLPStrategy strategy;
    ERC20 rewardToken;
    ERC20 lp;
    IUniswapV2Router01 router;

    function setUp() public override {
        forkFantom(44897336);
        super.setUp();

        SpookySwapStrategyV2 script = new SpookySwapStrategyV2();
        script.setTesting(true);
        (strategy) = script.run();

        degenBox = IBentoBoxV1(constants.getAddress("fantom.degenBox"));
        rewardToken = ERC20(constants.getAddress("fantom.spookyswap.boo"));
        lp = ERC20(constants.getAddress("fantom.spookyswap.wFtmMim"));

        _activateStrategy();
    }

    function testFarmRewards() public {
        uint256 previousAmount = rewardToken.balanceOf(address(strategy));
        _distributeRewards();

        vm.startPrank(deployer);
        strategy.safeHarvest(type(uint256).max, false, 0, false);
        vm.stopPrank();

        assertGt(rewardToken.balanceOf(address(strategy)), previousAmount, "no reward harvested");
    }

    function testFeeParameters() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        strategy.setFeeParameters(alice, 15);

        vm.prank(deployer);
        strategy.setFeeParameters(alice, 15);
        assertEq(strategy.feeCollector(), alice);
        assertEq(strategy.feePercent(), 15);
    }

    function testMintLpFromRewardsTakeFees() public {
        vm.prank(deployer);
        strategy.setFeeParameters(deployer, 10);

        _distributeRewards();

        vm.prank(deployer);
        strategy.safeHarvest(0, false, 0, false);

        uint256 balanceFeeCollector = lp.balanceOf(deployer);
        uint256 balanceStrategy = lp.balanceOf(address(strategy));
        vm.stopPrank();

        vm.expectEmit(false, false, false, false);
        emit LpMinted(0, 0, 0);

        vm.prank(deployer);
        strategy.swapToLP(0, address(rewardToken));

        // Strategy and FeeCollector should now have more LP
        assertGt(lp.balanceOf(deployer), balanceFeeCollector);
        assertGt(lp.balanceOf(address(strategy)), balanceStrategy);
    }

    function testStrategyProfit() public {
        uint256 degenBoxBalance = degenBox.totals(lp).elastic;

        _distributeRewards();

        vm.prank(deployer);
        strategy.safeHarvest(0, false, 0, false);

        vm.startPrank(deployer);
        strategy.swapToLP(0, address(rewardToken));

        vm.expectEmit(true, false, false, false);
        emit LogStrategyProfit(address(lp), 0);
        strategy.safeHarvest(0, false, 0, false);

        assertGt(degenBox.totals(lp).elastic, degenBoxBalance);
    }

    function testStrategyDivest() public {
        uint256 degenBoxBalance = lp.balanceOf(address(degenBox));

        vm.prank(degenBox.owner());
        degenBox.setStrategyTargetPercentage(lp, 50);

        vm.expectEmit(true, false, false, false);
        emit LogStrategyDivest(address(lp), 0);
        vm.prank(deployer);
        strategy.safeHarvest(0, true, 0, false);

        assertGt(lp.balanceOf(address(degenBox)), degenBoxBalance);
    }

    function testStrategyExit() public {
        uint256 degenBoxBalance = lp.balanceOf(address(degenBox));

        _distributeRewards();

        vm.prank(deployer);
        strategy.safeHarvest(0, true, 0, false);

        vm.prank(deployer);
        strategy.swapToLP(0, address(rewardToken));

        vm.expectEmit(true, true, false, false);
        emit LogStrategyQueued(address(lp), address(strategy));

        vm.startPrank(degenBox.owner());
        degenBox.setStrategy(lp, strategy);
        advanceTime(1210000);

        vm.expectEmit(true, false, false, false);
        emit LogStrategyDivest(address(lp), 0);
        degenBox.setStrategy(lp, strategy);
        vm.stopPrank();

        assertGt(lp.balanceOf(address(degenBox)), degenBoxBalance);
        assertEq(lp.balanceOf(address(strategy)), 0);
    }

    function _distributeRewards() private {
        advanceTime(1210000);
    }

    function _activateStrategy() private {
        uint256 amountLpDegenBox = lp.balanceOf(address(degenBox));
        (uint256 amountLpStaked, ) = farmV1.userInfo(24, wftmmimStrategyV1);
        assertGt(amountLpStaked, 0);

        // exit current v1 strat and switch to v2
        vm.startPrank(degenBox.owner());
        degenBox.setStrategy(lp, strategy);
        advanceTime(1210000);
        degenBox.setStrategy(lp, strategy);

        // check that v1 exit correctly
        (amountLpStaked, ) = farmV1.userInfo(24, wftmmimStrategyV1);
        assertEq(amountLpStaked, 0);
        assertGt(lp.balanceOf(address(degenBox)), amountLpDegenBox);
        assertEq(lp.balanceOf(wftmmimStrategyV1), 0);

        degenBox.setStrategyTargetPercentage(lp, 70);
        vm.stopPrank();

        // Initial Rebalance, calling skim to deposit to the gauge
        vm.startPrank(deployer);
        strategy.safeHarvest(type(uint256).max, true, 0, false);
        assertEq(lp.balanceOf(address(strategy)), 0);
        assertEq(rewardToken.balanceOf(address(strategy)), 0);
        vm.stopPrank();
    }
}
