// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IAggregator} from "interfaces/IAggregator.sol";
import {IUmbrellaFeeds} from "interfaces/IUmbrellaFeeds.sol";

interface IUmbrellaRegistry {
    function getAddress(bytes32 _bytes) external view returns (address);
}

/// @title UmbrellaAggregator
/// @notice Wraps umbrella price feed in an aggregator interface
contract UmbrellaAggregator is IAggregator {
    bytes32 public constant FEEDS_KEY_NAME = bytes32("UmbrellaFeeds");

    IUmbrellaRegistry public immutable registry;
    bytes32 public immutable key;

    constructor(bytes32 _key, IUmbrellaRegistry _registry) {
        key = _key;
        registry = _registry;
    }

    function decimals() external view override returns (uint8) {
        return _getFeeds().DECIMALS();
    }

    function latestAnswer() external view returns (int256 answer) {
        (, answer, , , ) = latestRoundData();
    }

    function latestRoundData() public view returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80) {
        IUmbrellaFeeds.PriceData memory data = _getFeeds().getPriceData(key);
        return (0, int256(uint256(data.price)), 0, data.timestamp, 0);
    }

    function _getFeeds() private view returns (IUmbrellaFeeds) {
        return IUmbrellaFeeds(registry.getAddress(FEEDS_KEY_NAME));
    }
}
