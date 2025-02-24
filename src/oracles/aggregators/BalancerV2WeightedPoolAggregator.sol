// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {SD59x18, sd, UNIT} from "@prb/math/SD59x18.sol";
import {BalancerV2VaultReentrancyLib} from "/libraries/BalancerV2VaultReentrancyLib.sol";
import {IBalancerV2Vault} from "/interfaces/IBalancerV2Vault.sol";
import {IBalancerV2WeightedPool} from "/interfaces/IBalancerV2WeightedPool.sol";
import {IPriceProvider} from "/interfaces/IPriceProvider.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";

contract BalancerV2WeightedPoolAggregator is IAggregator {
    using BalancerV2VaultReentrancyLib for IBalancerV2Vault;

    IBalancerV2Vault public immutable vault;
    IBalancerV2WeightedPool public immutable weightedPool;
    IPriceProvider public immutable priceProvider;
    bytes32 public immutable poolId;

    constructor(IBalancerV2Vault _vault, IBalancerV2WeightedPool _weightedPool, IPriceProvider _priceProvider) {
        vault = _vault;
        weightedPool = _weightedPool;
        priceProvider = _priceProvider;
        poolId = _weightedPool.getPoolId();
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function latestAnswer() external view override returns (int256 answer) {
        vault.ensureNotInVaultContext(); // Prevent reentrancy

        uint256[] memory weights = weightedPool.getNormalizedWeights();
        (address[] memory tokens, , ) = vault.getPoolTokens(poolId);
        SD59x18 totalSupply = sd(int256(weightedPool.totalSupply()));

        SD59x18 totalPi = UNIT;
        for (uint256 i = 0; i < tokens.length; ++i) {
            address token = tokens[i];
            SD59x18 price = sd(priceProvider.getPrice(token));
            SD59x18 weight = sd(int256(weights[i]));
            SD59x18 value = price / weight;
            SD59x18 pi = value.pow(weight);
            totalPi = totalPi * pi;
        }

        SD59x18 invariant = sd(int256(weightedPool.getInvariant()));
        SD59x18 totalValue = totalPi * invariant;
        return (totalValue / totalSupply).unwrap();
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, this.latestAnswer(), 0, 0, 0);
    }
}
