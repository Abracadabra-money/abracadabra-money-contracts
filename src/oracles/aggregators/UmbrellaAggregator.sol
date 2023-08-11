// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IAggregator.sol";
import "interfaces/IUmbrellaFeeds.sol";

/// @title UmbrellaAggregator
/// @notice Wraps umbrella price feed in an aggregator interface
contract UmbrellaAggregator is IAggregator {
    IUmbrellaFeeds public immutable feeds;
    bytes32 public immutable key;

    constructor(bytes32 _key, IUmbrellaFeeds _feeds) {
        key = _key;
        feeds = _feeds;
    }

    function decimals() external view override returns (uint8) {
        return feeds.DECIMALS();
    }

    function latestAnswer() external view returns (int256 answer) {
        (, answer, , , ) = latestRoundData();
    }

    function latestRoundData() public view returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80) {
        IUmbrellaFeeds.PriceData memory data = feeds.getPriceData(key);
        return (0, int256(uint256(data.price)), 0, data.timestamp, 0);
    }
}
