// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/OptimismStargateUsdc.s.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ICauldronV3.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";

contract OptimismStargateUsdcTest is BaseTest {
    address constant lpWhale = 0x4a364f8c717cAAD9A442737Eb7b8A55cc6cf18D8;

    // 0x OP -> USDC rewards
    bytes constant swapData =
        hex"415565b000000000000000000000000042000000000000000000000000000000000000420000000000000000000000007f5c764cbc14f9669b88837ca1490cca17c3160700000000000000000000000000000000000000000000004183039f439968b53a0000000000000000000000000000000000000000000000000000000088a917ef00000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000004c00000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000004200000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000042000000000000000000000000000000000000420000000000000000000000007f5c764cbc14f9669b88837ca1490cca17c31607000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000003e000000000000000000000000000000000000000000000000000000000000003e000000000000000000000000000000000000000000000000000000000000003a000000000000000000000000000000000000000000000004183039f439968b53a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000012556e69737761705633000000000000000000000000000000000000000000000000000000000000050a13f88f0bcd124a000000000000000000000000000000000000000000000000000000000a831cf3000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000e592427a0aece92de3edee1f18e0157c058615640000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000002b42000000000000000000000000000000000000420001f47f5c764cbc14f9669b88837ca1490cca17c316070000000000000000000000000000000000000000000000000000000000000000000000001d56656c6f64726f6d650000000000000000000000000000000000000000000000000000000000003c78efa6b48d9ba2f1000000000000000000000000000000000000000000000000000000007e25fafc00000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000040000000000000000000000000a132dab612db5cb9fc9ac426a0cc215a3423f9c900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000020000000000000000000000004200000000000000000000000000000000000042000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000000000000000000000000000000000000000000000869584cd000000000000000000000000100000000000000000000000000000000000001100000000000000000000000000000000000000000000005cdefad19962effe00";

    event LpMinted(uint256 total, uint256 strategyAmount, uint256 feeAmount);
    event LogStrategyProfit(address indexed token, uint256 amount);
    event LogStrategyDivest(address indexed token, uint256 amount);
    event LogStrategyQueued(address indexed token, address indexed strategy);

    ICauldronV3 cauldron;
    IBentoBoxV1 degenBox;
    ISwapperV2 swapper;
    ILevSwapperV2 levswapper;
    StargateLPStrategy strategy;
    ERC20 stgToken;
    ERC20 underlyingToken;
    ERC20 lp;
    IStargateLPStaking staking;
    IStargateRouter router;
    uint256 pid;

    function setUp() public override {
        super.setUp();

        vm.createSelectFork(vm.envString("OPTIMISM_RPC_URL"), 18150413);
        OptimismStargateUsdcScript script = new OptimismStargateUsdcScript();
        script.setTesting(true);
        (cauldron, swapper, levswapper, strategy) = script.run();

        degenBox = IBentoBoxV1(constants.getAddress("optimism.degenBox"));
        router = IStargateRouter(constants.getAddress("optimism.stargate.router"));
        stgToken = ERC20(constants.getAddress("optimism.stargate.stg"));
        lp = ERC20(constants.getAddress("optimism.stargate.usdcPool"));
        staking = IStargateLPStaking(constants.getAddress("optimism.stargate.staking"));
        underlyingToken = ERC20(address(strategy.underlyingToken()));
        pid = strategy.pid();

        _transferLpToDegenBox();
        _activateStrategy();

        advanceTime(1210000);
    }

    function _transferLpToDegenBox() private {
        uint256 lpAmount = 2_000_000 * 1e6;

        vm.prank(lpWhale);
        lp.transfer(address(degenBox), lpAmount);
        degenBox.deposit(lp, address(degenBox), address(degenBox), lpAmount, 0);
    }

    function _activateStrategy() private {
        vm.startPrank(degenBox.owner());
        degenBox.setStrategy(lp, strategy);
        advanceTime(1210000);
        degenBox.setStrategy(lp, strategy);
        degenBox.setStrategyTargetPercentage(lp, 70);
        vm.stopPrank();

        vm.startPrank(deployer);
        strategy.safeHarvest(type(uint256).max, true, 0, false);
        assertEq(lp.balanceOf(address(strategy)), 0);
        assertEq(stgToken.balanceOf(address(strategy)), 0);
        vm.stopPrank();
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

        vm.startPrank(deployer);
        strategy.safeHarvest(0, false, 0, false);

        uint256 balanceFeeCollector = lp.balanceOf(deployer);
        uint256 balanceStrategy = lp.balanceOf(address(strategy));
        vm.stopPrank();

        vm.startPrank(deployer);
        strategy.swapToLP(0, swapData);

        // Strategy and FeeCollector should now have more LP
        assertGt(lp.balanceOf(deployer), balanceFeeCollector, "no lp minted to fee collector");
        assertGt(lp.balanceOf(address(strategy)), balanceStrategy, "no lp minted to strategy");
        vm.stopPrank();
    }

    function testStrategyProfit() public {
        uint256 degenBoxBalance = degenBox.totals(lp).elastic;

        vm.prank(deployer);
        strategy.safeHarvest(0, false, 0, false);

        vm.startPrank(deployer);
        strategy.swapToLP(0, swapData);

        vm.expectEmit(true, false, false, false);
        emit LogStrategyProfit(address(lp), 0);
        strategy.safeHarvest(0, false, 0, false);

        assertGt(degenBox.totals(lp).elastic, degenBoxBalance);
    }

    function testStrategyDivest() public {
        uint256 degenBoxBalance = lp.balanceOf(address(degenBox));

        vm.prank(degenBox.owner());
        degenBox.setStrategyTargetPercentage(lp, 50);

        vm.startPrank(deployer);
        vm.expectEmit(true, false, false, false);
        emit LogStrategyDivest(address(lp), 0);
        strategy.safeHarvest(0, true, 0, false);

        assertGt(lp.balanceOf(address(degenBox)), degenBoxBalance);
    }

    function testStrategyExit() public {
        uint256 degenBoxBalance = lp.balanceOf(address(degenBox));

        vm.prank(deployer);
        strategy.safeHarvest(0, true, 0, false);

        vm.prank(deployer);
        strategy.swapToLP(0, swapData);

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
}
