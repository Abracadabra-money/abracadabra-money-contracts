// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IPriceProvider} from "../interfaces/IPriceProvider.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";

contract AggregatorPriceProvider is IPriceProvider {
    struct TokenAggregator {
        address token;
        IAggregator aggregator;
    }

    error ErrUnsupportedToken();
    uint256 internal constant WAD = 18;

    mapping(address => IAggregator) public aggregators;

    constructor(TokenAggregator[] memory _tokenAggregators) {
        for (uint256 i = 0; i < _tokenAggregators.length; ++i) {
            TokenAggregator memory tokenAggregator = _tokenAggregators[i];
            aggregators[tokenAggregator.token] = tokenAggregator.aggregator;
        }
    }

    function getPrice(address token) external view override returns (int256) {
        IAggregator aggregator = aggregators[token];

        require(address(aggregator) != address(0), ErrUnsupportedToken());

        (, int256 price, , , ) = aggregator.latestRoundData();
        uint8 decimals = aggregator.decimals();
        return price * (int256(10) ** (WAD - decimals));
    }
}
