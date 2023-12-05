// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/GmStrategy.s.sol";

import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {RebaseLibrary, Rebase} from "BoringSolidity/libraries/BoringRebase.sol";
import {IMultiRewardsStaking} from "interfaces/IMultiRewardsStaking.sol";

contract GmStrategyTestBase is BaseTest {
    using BoringERC20 for IERC20;
    using RebaseLibrary for Rebase;

    event LogStrategySet(IERC20 indexed token, GmStrategy indexed strategy);
    event LogStrategyQueued(IERC20 indexed token, GmStrategy indexed strategy);
    event LogLpMinted(uint256 total, uint256 strategyAmount, uint256 feeAmount);

    uint256 constant STRATEGY_TOKEN_DECIMALS = 18;

    IERC20 strategyToken;
    GmStrategy strategy;
    IBentoBoxV1 box;
    IMultiRewardsStaking staking;

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

        _setupStrategy();
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

        assertApproxEqAbs((shareInBox * (100 - stratPercentage)) / 100, strategyToken.balanceOf(address(box)), 1, "not correct amount in degenbox");

        // Investing in a strategy shouldn't change total elastic and base
        Rebase memory totals2 = box.totals(strategyToken);
        assertEq(totals.elastic, totals2.elastic, "elastic changed");
        assertEq(totals.base, totals2.base, "base changed");

        stakedAmount = staking.balanceOf(address(strategy));
        assertApproxEqAbs(stakedAmount, (amountInBox * stratPercentage) / 100, 1, "staking amount not correct");
    }

    function test() public {}
}

contract GmArbStrategyTest is GmStrategyTestBase {
    function setUp() public override {
        GmStrategyScript script = super.initialize();
        (strategy, , , ) = script.deploy();
        super.afterDeployed();
    }
}

contract GmEthStrategyTest is GmStrategyTestBase {
    function setUp() public override {
        GmStrategyScript script = super.initialize();
        (, strategy, , ) = script.deploy();
        super.afterDeployed();
    }
}

contract GmBTCStrategyTest is GmStrategyTestBase {
    function setUp() public override {
        GmStrategyScript script = super.initialize();
        (, , strategy, ) = script.deploy();
        super.afterDeployed();
    }
}

contract GmSolStrategyTest is GmStrategyTestBase {
    function setUp() public override {
        GmStrategyScript script = super.initialize();
        (, , , strategy) = script.deploy();
        super.afterDeployed();
    }
}
