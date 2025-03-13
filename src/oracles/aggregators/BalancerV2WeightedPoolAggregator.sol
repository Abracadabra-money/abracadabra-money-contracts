// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {SD59x18, sd, UNIT} from "@prb/math/SD59x18.sol";
import {PRBMathCastingUint256} from "@prb/math/casting/Uint256.sol";
import {BalancerV2VaultReentrancyLib} from "/libraries/BalancerV2VaultReentrancyLib.sol";
import {IBalancerV2Vault} from "/interfaces/IBalancerV2Vault.sol";
import {IBalancerV2WeightedPool} from "/interfaces/IBalancerV2WeightedPool.sol";
import {IPriceProvider} from "/interfaces/IPriceProvider.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";

/// @dev This aggregator should not be used for Preminted BPT.
/// Uses getActualSupply, thus it only works for modern BPTs.
contract BalancerV2WeightedPoolAggregator is IAggregator {
    using BalancerV2VaultReentrancyLib for IBalancerV2Vault;
    using PRBMathCastingUint256 for uint256;

    error ErrLengthMismatch();
    error ErrAddressZero();

    IBalancerV2Vault public immutable vault;
    IBalancerV2WeightedPool public immutable weightedPool;
    bytes32 public immutable poolId;

    IAggregator[] public aggregators;
    address[] public tokens;

    constructor(IBalancerV2Vault _vault, IBalancerV2WeightedPool _weightedPool, IAggregator[] memory _aggregators) {
        vault = _vault;
        weightedPool = _weightedPool;
        poolId = _weightedPool.getPoolId();

        (tokens, , ) = vault.getPoolTokens(poolId);
        require(_aggregators.length == tokens.length, ErrLengthMismatch());

        for (uint256 i = 0; i < _aggregators.length; ++i) {
            require(address(_aggregators[i]) != address(0), ErrAddressZero());
            aggregators.push(_aggregators[i]);
        }
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function latestAnswer() external view override returns (int256 answer) {
        vault.ensureNotInVaultContext(); // Prevent reentrancy

        uint256[] memory weights = weightedPool.getNormalizedWeights();
        SD59x18 totalSupply = weightedPool.getActualSupply().intoSD59x18();

        SD59x18 totalPi = UNIT;
        for (uint256 i = 0; i < tokens.length; ++i) {
            SD59x18 price = sd(_getPrice(i));
            SD59x18 weight = sd(int256(weights[i]));
            SD59x18 value = price / weight;
            SD59x18 pi = value.pow(weight);
            totalPi = totalPi * pi;
        }

        SD59x18 invariant = weightedPool.getInvariant().intoSD59x18();
        SD59x18 totalValue = totalPi * invariant;
        return (totalValue / totalSupply).unwrap();
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, this.latestAnswer(), 0, 0, 0);
    }

    function _getPrice(uint256 index) internal view returns (int256) {
        IAggregator aggregator = aggregators[index];
        (, int256 price, , , ) = aggregator.latestRoundData();
        uint8 _decimals = aggregator.decimals();
        return (price * (int256(10) ** 18)) / (int256(10) ** _decimals);
    }
}
