// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20 as BoringERC20} from "BoringSolidity/ERC20.sol";
import {StargateLpCauldronScript} from "script/StargateLpCauldron.s.sol";
import {ExchangeRouterMock} from "./mocks/ExchangeRouterMock.sol";
import {IStrategy} from "interfaces/IStrategy.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {StargateLPStrategy} from "strategies/StargateLPStrategy.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {IStargateLPStaking} from "interfaces/IStargateLPStaking.sol";
import "utils/BaseTest.sol";
import "BoringSolidity/libraries/BoringRebase.sol";

contract StargateLPStrategyTestBase is BaseTest {
    using RebaseLibrary for Rebase;

    event LogStrategySet(IERC20 indexed token, StargateLPStrategy indexed strategy);
    event LogStrategyQueued(IERC20 indexed token, StargateLPStrategy indexed strategy);
    event LogLpMinted(uint256 total, uint256 strategyAmount, uint256 feeAmount);

    StargateLPStrategy strategy;
    IBentoBoxV1 box;
    IStargateLPStaking staking;
    IERC20 lp;
    IERC20 rewardToken;
    uint256 initialLpAmount;
    uint256 pid;
    uint256 lpDecimals;
    ExchangeRouterMock mockRouter;
    IERC20 underlyingToken;

    function initialize(uint256 chainId, uint256 blockNumber, uint256 _lpDecimals) public returns (StargateLpCauldronScript script) {
        fork(chainId, blockNumber);
        super.setUp();

        script = new StargateLpCauldronScript();
        script.setTesting(true);

        lpDecimals = _lpDecimals;
    }

    function afterDeployed() public {
        box = IBentoBoxV1(strategy.bentoBox());
        assertNotEq(address(box), address(0));

        lp = IERC20(strategy.strategyToken());
        staking = IStargateLPStaking(strategy.staking());
        pid = strategy.pid();
        rewardToken = IERC20(strategy.rewardToken());
        underlyingToken = IERC20(strategy.underlyingToken());
        mockRouter = new ExchangeRouterMock(BoringERC20(address(rewardToken)), BoringERC20(address(underlyingToken)));

        pushPrank(strategy.owner());
        strategy.setStargateSwapper(address(mockRouter));
        popPrank();

        _setupStrategy();
    }

    function testHarvest() public {
        (uint256 stakedAmount, ) = staking.userInfo(pid, address(strategy));

        uint256 rewardTokenBalance = rewardToken.balanceOf(address(strategy));
        advanceTime(7 days);

        // harvest rewards
        pushPrank(strategy.owner());
        strategy.safeHarvest(type(uint256).max, true, 0, false);
        popPrank();

        uint256 rewards = rewardToken.balanceOf(address(strategy));
        assertGt(rewards, rewardTokenBalance);

        // for simplicity just assume we get the same amount of underlying tokens
        deal(address(underlyingToken), address(mockRouter), rewards);

        pushPrank(strategy.owner());
        vm.expectEmit(false, false, false, false);
        emit LogLpMinted(0, 0, 0);
        strategy.swapToLP(0, "");

        // we should have minted from LP
        assertGt(lp.balanceOf(address(strategy)), 0);

        // harvest again to deposit the new amount to staking
        pushPrank(strategy.owner());
        strategy.safeHarvest(type(uint256).max, true, 0, false);
        popPrank();

        (uint256 stakedAmount2, ) = staking.userInfo(pid, address(strategy));
        assertGt(stakedAmount2, stakedAmount, "nothing more deposited to staking?");

        popPrank();
    }

    function testChangeStrategyPercentage() public {
        testHarvest();

        (uint256 stakedAmount, ) = staking.userInfo(pid, address(strategy));

        pushPrank(box.owner());
        box.setStrategyTargetPercentage(lp, 50);
        popPrank();

        pushPrank(strategy.owner());
        strategy.safeHarvest(type(uint256).max, true, 0, false);
        popPrank();

        (uint256 stakedAmount2, ) = staking.userInfo(pid, address(strategy));
        assertLt(stakedAmount2, stakedAmount, "nothing removed from staking?");
        assertEq(lp.balanceOf(address(strategy)), 0);

        pushPrank(box.owner());
        box.setStrategyTargetPercentage(lp, 0);
        popPrank();

        pushPrank(strategy.owner());
        strategy.safeHarvest(type(uint256).max, true, 0, false);
        popPrank();

        (stakedAmount, ) = staking.userInfo(pid, address(strategy));
        assertEq(stakedAmount, 0, "still something in staking?");
        assertEq(lp.balanceOf(address(strategy)), 0);
    }

    function testExitStrategy() public {
        testHarvest();

        Rebase memory totals = box.totals(lp);
        assertGt(totals.elastic, lp.balanceOf(address(box)));

        // any non-zero address will do
        IStrategy dummy = IStrategy(address(0xdeadbeef));

        // Set Strategy on LP
        pushPrank(box.owner());
        box.setStrategy(lp, dummy);
        advanceTime(3 days);
        box.setStrategy(lp, dummy);
        popPrank();

        assertEq(totals.elastic, lp.balanceOf(address(box)));
    }

    function _setupStrategy() internal {
        uint64 stratPercentage = 70;

        assertNotEq(address(strategy), address(0));

        // Set Strategy on LP
        pushPrank(box.owner());
        vm.expectEmit(true, true, true, true);
        emit LogStrategyQueued(lp, strategy);
        box.setStrategy(lp, strategy);
        advanceTime(3 days);
        vm.expectEmit(true, true, true, true);
        emit LogStrategySet(lp, strategy);
        box.setStrategy(lp, strategy);
        assertEq(address(box.strategy(lp)), address(strategy));
        box.setStrategyTargetPercentage(lp, stratPercentage);
        popPrank();

        uint256 lpAmount = 100_000 * (10 ** lpDecimals);
        deal(address(lp), address(box), lpAmount);
        box.deposit(lp, address(box), address(alice), lpAmount, 0);

        Rebase memory totals = box.totals(lp);
        (uint256 stakedAmount, ) = staking.userInfo(pid, address(strategy));
        assertEq(stakedAmount, 0);

        totals = box.totals(lp);
        uint256 shareInBox = lp.balanceOf(address(box));

        // Initial Rebalance, calling skim to stake
        pushPrank(strategy.owner());
        strategy.safeHarvest(type(uint256).max, true, 0, false);
        assertEq(lp.balanceOf(address(strategy)), 0);
        popPrank();

        assertEq((shareInBox * (100 - stratPercentage)) / 100, lp.balanceOf(address(box)));

        // Investing in a strategy shouldn't change total elastic and base
        Rebase memory totals2 = box.totals(lp);
        assertEq(totals.elastic, totals2.elastic);
        assertEq(totals.base, totals2.base);

        (stakedAmount, ) = staking.userInfo(pid, address(strategy));
        assertEq(stakedAmount, (lpAmount * stratPercentage) / 100);
    }
}

contract KavaStargateLPStrategyTest is StargateLPStrategyTestBase {
    function setUp() public override {
        StargateLpCauldronScript script = super.initialize(ChainId.Kava, 6476735, 6 /* S*USDT is 6 decimals */);
        (strategy) = script.deploy();
        super.afterDeployed();
    }
}
