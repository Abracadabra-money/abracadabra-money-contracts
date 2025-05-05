// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";
import {BabylonianLib} from "/libraries/BabylonianLib.sol";
import {IKodiakVaultV1} from "/interfaces/IKodiak.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {MathLib} from "/libraries/MathLib.sol";

contract KodiakIslandAggregator is IAggregator {
    uint256 public constant WAD = 18;

    error ErrInvalidDecimals();

    IAggregator public immutable tokenAggregator0;
    IAggregator public immutable tokenAggregator1;

    uint256 public immutable aggregatorDecimalScale0;
    uint256 public immutable aggregatorDecimalScale1;

    IKodiakVaultV1 public immutable island;
    address public immutable token0;
    address public immutable token1;
    uint8 public immutable decimals0;
    uint8 public immutable decimals1;

    uint8 public immutable override decimals;

    constructor(IKodiakVaultV1 _island, IAggregator _tokenAggregator0, IAggregator _tokenAggregator1) {
        island = _island;
        tokenAggregator0 = _tokenAggregator0;
        tokenAggregator1 = _tokenAggregator1;
        token0 = island.token0();
        token1 = island.token1();
        decimals0 = IERC20Metadata(token0).decimals();
        decimals1 = IERC20Metadata(token1).decimals();
        aggregatorDecimalScale0 = 10 ** (WAD - tokenAggregator0.decimals());
        aggregatorDecimalScale1 = 10 ** (WAD - tokenAggregator1.decimals());
        decimals = IERC20Metadata(address(island)).decimals();

        require(decimals == WAD, ErrInvalidDecimals());
    }

    function latestAnswer() public view override returns (int256) {
        (, int256 feed0, , , ) = tokenAggregator0.latestRoundData();
        (, int256 feed1, , , ) = tokenAggregator1.latestRoundData();

        uint256 priceFeed_token0 = uint256(feed0) * aggregatorDecimalScale0;
        uint256 priceFeed_token1 = uint256(feed1) * aggregatorDecimalScale1;

        uint decimalMultiplier;
        uint decimalDivider;
        uint decimalDifference = MathLib.absoluteDifference(decimals0, decimals1);
        if (decimals0 >= decimals1) {
            decimalMultiplier = 1;
            decimalDivider = 10 ** decimalDifference;
        } else {
            decimalMultiplier = 10 ** decimalDifference;
            decimalDivider = 1;
        }

        uint priceRatio = (priceFeed_token0 * decimalMultiplier * 1e18) / (priceFeed_token1 * decimalDivider);

        uint160 price_sqrtRatioX96 = SafeCast.toUint160((BabylonianLib.sqrt(priceRatio) * (2 ** 96)) / 1e9);

        // Note: getUnderlyingBalancesAtPrice gets the reserves at a specified price based on UniV3 curve math + accumulated fees + token balances in contract
        // The token reserve math is as described here: https://docs.parallel.fi/parallel-finance/staking-and-derivative-token-yield-management/borrow-against-uniswap-v3-lp-tokens/uniswap-v3-lp-token-analyzer
        // As we use oracle price (rather than current bock pool balances) to get the reserves, this calculation isn't subject to flash loan exploit
        (uint reserve0, uint reserve1) = IKodiakVaultV1(island).getUnderlyingBalancesAtPrice(price_sqrtRatioX96);

        uint normalizedReserve0 = reserve0 * (10 ** (18 - decimals0));
        uint normalizedReserve1 = reserve1 * (10 ** (18 - decimals1));

        uint totalSupply = IKodiakVaultV1(island).totalSupply();

        if (totalSupply == 0) return 0;

        uint totalValue = normalizedReserve0 * priceFeed_token0 + normalizedReserve1 * priceFeed_token1;

        return SafeCast.toInt256(totalValue / totalSupply);
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, latestAnswer(), 0, 0, 0);
    }
}
