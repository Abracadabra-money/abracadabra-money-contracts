// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/StargateLPStrategy.s.sol";
import "BoringSolidity/libraries/BoringRebase.sol";

contract StargateLPStrategyTestBase is BaseTest {
    using RebaseLibrary for Rebase;

    event LogStrategySet(IERC20 indexed token, StargateLPStrategy indexed strategy);
    event LogStrategyQueued(IERC20 indexed token, StargateLPStrategy indexed strategy);

    StargateLPStrategy strategy;
    IBentoBoxV1 box;
    IStargateLPStaking staking;
    IERC20 lp;
    uint256 initialLpAmount;
    uint256 pid;
    uint256 lpDecimals;

    function initialize(uint256 chainId, uint256 blockNumber, uint256 _lpDecimals) public returns (StargateLPStrategyScript script) {
        fork(chainId, blockNumber);
        super.setUp();

        script = new StargateLPStrategyScript();
        script.setTesting(true);

        lpDecimals = _lpDecimals;
    }

    function afterDeployed() public {
        box = IBentoBoxV1(strategy.bentoBox());
        assertNotEq(address(box), address(0));

        lp = IERC20(strategy.strategyToken());
        staking = IStargateLPStaking(strategy.staking());
        pid = strategy.pid();

        _setupStrategy();
    }

    function test() public {}

    function _setupStrategy() internal {
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
        box.setStrategyTargetPercentage(lp, 70);
        popPrank();

        Rebase memory totals = box.totals(lp);
        deal(address(lp), address(box), 10_000 * (10 ** lpDecimals));

        // First Harvest To Stake
        pushPrank(strategy.owner());
        // Initial Rebalance, calling skim to deposit to pool
        strategy.safeHarvest(type(uint256).max, true, 0, false);
        assertEq(lp.balanceOf(address(strategy)), 0);
        popPrank();

        totals = box.totals(lp);

        console2.log(totals.elastic, totals.base);
    }
}

contract KavaStargateLPStrategyTest is StargateLPStrategyTestBase {
    function setUp() public override {
        StargateLPStrategyScript script = super.initialize(ChainId.Kava, 6476735, 6 /* S*USDT is 6 decimals */);
        (strategy) = script.deploy();
        super.afterDeployed();

        (address lpToken, uint256 allocPoint, uint256 lastRewardBlock, uint256 accEmissionPerShare) = staking.poolInfo(pid);
        uint256 blockTo = lastRewardBlock + 10000;
        console2.log("Advancing to block number %s", blockTo);
        advanceBlocks(blockTo);
    }
}
