// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/GmStrategy.s.sol";

import {ERC20} from "BoringSolidity/ERC20.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {RebaseLibrary, Rebase} from "BoringSolidity/libraries/BoringRebase.sol";
import {IMultiRewardsStaking} from "interfaces/IMultiRewardsStaking.sol";
import {GmTestLib} from "./utils/GmTestLib.sol";
import {IGmxV2DepositCallbackReceiver} from "interfaces/IGmxV2.sol";
import {ExchangeRouterMock} from "./mocks/ExchangeRouterMock.sol";
import {IStrategy} from "interfaces/IStrategy.sol";

contract GmStrategyTestBase is BaseTest {
    using BoringERC20 for IERC20;
    using RebaseLibrary for Rebase;

    event LogStrategySet(IERC20 indexed token, GmStrategy indexed strategy);
    event LogStrategyProfit(IERC20 indexed token, uint256 amount);
    event LogStrategyQueued(IERC20 indexed token, GmStrategy indexed strategy);
    event LogMarketMinted(uint256 total, uint256 strategyAmount, uint256 feeAmount);

    uint256 constant STRATEGY_TOKEN_DECIMALS = 18;

    IERC20 strategyToken;
    IERC20 rewardToken;

    GmStrategy strategy;
    IBentoBoxV1 box;
    IMultiRewardsStaking staking;
    ExchangeRouterMock exchange;
    address usdc;
    address arb;

    function initialize() public returns (GmStrategyScript script) {
        fork(ChainId.Arbitrum, 157126186);
        super.setUp();

        script = new GmStrategyScript();
        script.setTesting(true);
    }

    function afterDeployed() public {
        box = IBentoBoxV1(strategy.bentoBox());
        strategyToken = strategy.strategyToken();
        staking = strategy.STAKING();
        rewardToken = IERC20(staking.rewardTokens(0));
        arb = toolkit.getAddress(block.chainid, "arb");
        usdc = toolkit.getAddress(block.chainid, "usdc");

        // prepare mock exchange for ARB -> USDC swapping
        exchange = new ExchangeRouterMock(ERC20(arb), ERC20(usdc));
        deal(usdc, address(exchange), 100_000e6);

        pushPrank(strategy.owner());
        strategy.setExchange(address(exchange));
        strategy.setTokenApproval(arb, address(exchange), type(uint256).max);
        popPrank();

        _setupStrategy();
    }

    function _testChangeStrategyPercentage() internal {
        uint256 stakedAmount = staking.balanceOf(address(strategy));
        assertGt(stakedAmount, 0, "staking amount not correct");

        pushPrank(box.owner());
        box.setStrategyTargetPercentage(strategyToken, 50);
        popPrank();

        pushPrank(strategy.owner());
        strategy.safeHarvest(type(uint256).max, true, 0, false);
        popPrank();

        uint256 stakedAmount2 = staking.balanceOf(address(strategy));
        assertGt(stakedAmount2, stakedAmount, "nothing added from staking?");
        assertEq(strategyToken.balanceOf(address(strategy)), 0);

        pushPrank(box.owner());
        box.setStrategyTargetPercentage(strategyToken, 0);
        popPrank();

        pushPrank(strategy.owner());
        strategy.safeHarvest(type(uint256).max, true, 0, false);
        popPrank();

        stakedAmount = staking.balanceOf(address(strategy));
        assertEq(stakedAmount, 0, "still something in staking?");
        assertEq(strategyToken.balanceOf(address(strategy)), 0);
    }

    function _testExitStrategy() internal {
        Rebase memory totals = box.totals(strategyToken);
        assertGt(totals.elastic, strategyToken.balanceOf(address(box)));

        // any non-zero address will do
        IStrategy dummy = IStrategy(address(0xdeadbeef));

        // Set Strategy on LP
        pushPrank(box.owner());
        box.setStrategy(strategyToken, dummy);
        advanceTime(3 days);
        box.setStrategy(strategyToken, dummy);
        popPrank();

        assertEq(totals.elastic, strategyToken.balanceOf(address(box)));
    }

    function _testHarvest(address marketInputToken, bytes memory swapData) internal {
        _distributeReward(rewardToken, 100_000 ether);

        uint256 stakedAmount = staking.balanceOf(address(strategy));
        uint256 rewardTokenBalance = rewardToken.balanceOf(address(strategy));
        assertEq(rewardTokenBalance, 0, "reward token balance not 0");
        advanceTime(7 days);

        uint256 rewardToClaim = staking.earned(address(strategy), address(rewardToken));
        assertGt(rewardToClaim, 0, "no reward to claim");

        pushPrank(strategy.owner());
        strategy.run{value: 1 ether}(address(rewardToken), marketInputToken, 0, 1 ether, swapData, 1000, 1);
        deal(address(strategyToken), address(strategy), 1 ether);

        assertGt(strategy.feeBips(), 0, "fee bips not set");
        uint256 fee = (1 ether * uint256(strategy.feeBips())) / 10_000;

        vm.expectEmit(true, true, true, true);
        emit LogMarketMinted(1 ether, 1 ether - fee, fee);

        vm.expectEmit(true, false, false, false);
        emit LogStrategyProfit(strategyToken, 0);

        GmTestLib.callAfterDepositExecution(IGmxV2DepositCallbackReceiver(address(strategy)));
        popPrank();

        uint256 stakedAmountAfter = staking.balanceOf(address(strategy));
        assertGt(stakedAmountAfter, stakedAmount, "staking amount not increased");
    }

    function _setupStrategy() internal {
        uint64 stratPercentage = 1;
        assertNotEq(address(strategy), address(0), "strategy not set");

        pushPrank(box.owner());
        vm.expectEmit(true, true, true, true);
        emit LogStrategyQueued(strategyToken, strategy);
        box.setStrategy(strategyToken, strategy);
        advanceTime(3 days);
        vm.expectEmit(true, true, true, true);
        emit LogStrategySet(strategyToken, strategy);
        box.setStrategy(strategyToken, strategy);
        assertEq(address(box.strategy(strategyToken)), address(strategy), "strategy not set");
        box.setStrategyTargetPercentage(strategyToken, stratPercentage);
        popPrank();

        uint256 strategyTokenAmount = 100_000 * (10 ** STRATEGY_TOKEN_DECIMALS);
        deal(address(strategyToken), address(alice), strategyTokenAmount);

        pushPrank(alice);
        strategyToken.approve(address(box), type(uint256).max);
        box.deposit(strategyToken, address(alice), address(alice), strategyTokenAmount, 0);
        popPrank();

        Rebase memory totals = box.totals(strategyToken);
        uint256 stakedAmount = staking.balanceOf(address(strategy));
        assertEq(stakedAmount, 0, "staking amount not correct");

        totals = box.totals(strategyToken);
        uint256 shareInBox = strategyToken.balanceOf(address(box));
        uint256 amountInBox = box.toAmount(strategyToken, shareInBox, false);

        assertGt(shareInBox, 0, "not market token in degenbox");

        // Initial Rebalance, calling skim to stake
        pushPrank(strategy.owner());
        strategy.safeHarvest(type(uint256).max, true, 0, false);
        assertEq(strategyToken.balanceOf(address(strategy)), 0, "strategy token not harvested");
        popPrank();

        assertApproxEqAbs(
            (shareInBox * (100 - stratPercentage)) / 100,
            strategyToken.balanceOf(address(box)),
            1,
            "not correct amount in degenbox"
        );

        // Investing in a strategy shouldn't change total elastic and base
        Rebase memory totals2 = box.totals(strategyToken);
        assertEq(totals.elastic, totals2.elastic, "elastic changed");
        assertEq(totals.base, totals2.base, "base changed");

        stakedAmount = staking.balanceOf(address(strategy));
        assertApproxEqAbs(stakedAmount, (amountInBox * stratPercentage) / 100, 1, "staking amount not correct");
    }

    function _distributeReward(IERC20 _rewardToken, uint256 _amount) internal {
        pushPrank(staking.owner());
        deal(address(_rewardToken), staking.owner(), _amount);
        _rewardToken.approve(address(staking), _amount);
        staking.notifyRewardAmount(address(_rewardToken), _amount);
        popPrank();
    }
}

contract GmArbStrategyTest is GmStrategyTestBase {
    function setUp() public override {
        GmStrategyScript script = super.initialize();
        (strategy, , , , ) = script.deploy();
        super.afterDeployed();
    }

    function testHarvest() public {
        _testHarvest(arb, "");
    }

    function testChangeStrategyPercentage() public {
        _testHarvest(arb, "");
        _testChangeStrategyPercentage();
    }

    function testExitStrategy() public {
        _testHarvest(arb, "");
        _testExitStrategy();
    }
}

contract GmEthStrategyTest is GmStrategyTestBase {
    function setUp() public override {
        GmStrategyScript script = super.initialize();
        (, strategy, , , ) = script.deploy();
        super.afterDeployed();
    }

    function testHarvest() public {
        _testHarvest(usdc, abi.encodeWithSelector(ExchangeRouterMock.swap.selector, address(strategy)));
    }

    function testChangeStrategyPercentage() public {
        _testHarvest(usdc, abi.encodeWithSelector(ExchangeRouterMock.swap.selector, address(strategy)));
        _testChangeStrategyPercentage();
    }

    function testExitStrategy() public {
        _testHarvest(usdc, abi.encodeWithSelector(ExchangeRouterMock.swap.selector, address(strategy)));
        _testExitStrategy();
    }
}

contract GmBTCStrategyTest is GmStrategyTestBase {
    function setUp() public override {
        GmStrategyScript script = super.initialize();
        (, , strategy, , ) = script.deploy();
        super.afterDeployed();
    }

    function testHarvest() public {
        _testHarvest(usdc, abi.encodeWithSelector(ExchangeRouterMock.swap.selector, address(strategy)));
    }

    function testChangeStrategyPercentage() public {
        _testHarvest(usdc, abi.encodeWithSelector(ExchangeRouterMock.swap.selector, address(strategy)));
        _testChangeStrategyPercentage();
    }

    function testExitStrategy() public {
        _testHarvest(usdc, abi.encodeWithSelector(ExchangeRouterMock.swap.selector, address(strategy)));
        _testExitStrategy();
    }
}

contract GmSolStrategyTest is GmStrategyTestBase {
    function setUp() public override {
        GmStrategyScript script = super.initialize();
        (, , , strategy, ) = script.deploy();
        super.afterDeployed();
    }

    function testHarvest() public {
        _testHarvest(usdc, abi.encodeWithSelector(ExchangeRouterMock.swap.selector, address(strategy)));
    }

    function testChangeStrategyPercentage() public {
        _testHarvest(usdc, abi.encodeWithSelector(ExchangeRouterMock.swap.selector, address(strategy)));
        _testChangeStrategyPercentage();
    }

    function testExitStrategy() public {
        _testHarvest(usdc, abi.encodeWithSelector(ExchangeRouterMock.swap.selector, address(strategy)));
        _testExitStrategy();
    }
}

contract GmLinkStrategyTest is GmStrategyTestBase {
    function setUp() public override {
        GmStrategyScript script = super.initialize();
        (, , , , strategy) = script.deploy();
        super.afterDeployed();
    }

    function testHarvest() public {
        _testHarvest(usdc, abi.encodeWithSelector(ExchangeRouterMock.swap.selector, address(strategy)));
    }

    function testChangeStrategyPercentage() public {
        _testHarvest(usdc, abi.encodeWithSelector(ExchangeRouterMock.swap.selector, address(strategy)));
        _testChangeStrategyPercentage();
    }

    function testExitStrategy() public {
        _testHarvest(usdc, abi.encodeWithSelector(ExchangeRouterMock.swap.selector, address(strategy)));
        _testExitStrategy();
    }
}
