// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseTest.sol";
import {BalancerV2WeightedPoolAggregator} from "/oracles/aggregators/BalancerV2WeightedPoolAggregator.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";
import {IBalancerV2Vault} from "/interfaces/IBalancerV2Vault.sol";
import {IBalancerV2WeightedPool} from "/interfaces/IBalancerV2WeightedPool.sol";
import {IPriceProvider} from "/interfaces/IPriceProvider.sol";
import {FixedPriceAggregator} from "/oracles/aggregators/FixedPriceAggregator.sol";

contract BalancerV2WeightedPoolAggregatorTest is BaseTest {
    IBalancerV2Vault vault;
    IBalancerV2WeightedPool weightedPool;
    IAggregator[] aggregators;
    BalancerV2WeightedPoolAggregator poolAggregator;

    function setUp() public override {
        fork(ChainId.Bera, 1429069);
        super.setUp();
        vault = IBalancerV2Vault(toolkit.getAddress("bex.vault"));
        weightedPool = IBalancerV2WeightedPool(toolkit.getAddress("bex.wberahoney"));
        
        // Create array of aggregators instead of using PriceProvider
        aggregators = new IAggregator[](2);
        aggregators[0] = new FixedPriceAggregator(8.21 ether, 18);
        aggregators[1] = new FixedPriceAggregator(1 ether, 18);

        poolAggregator = new BalancerV2WeightedPoolAggregator(vault, weightedPool, aggregators);
    }

    function testAggregator() public view {
        (address[] memory tokens, uint256[] memory balances, ) = vault.getPoolTokens(weightedPool.getPoolId());
        uint256 tvl = 0;
        for (uint256 i = 0; i < tokens.length; ++i) {
            (, int256 price, , , ) = aggregators[i].latestRoundData();
            tvl += (balances[i] * uint256(price)) / 1e18;
        }
        assertApproxEqRelDecimal(uint256(poolAggregator.latestAnswer()), (tvl * 1e18) / weightedPool.totalSupply(), 0.0001 ether, 18);
    }
}
