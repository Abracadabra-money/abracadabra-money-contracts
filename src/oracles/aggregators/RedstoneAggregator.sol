// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IAggregator} from "interfaces/IAggregator.sol";

interface IRedstoneAdapter {
    function getValueForDataFeed(bytes32 dataFeedId) external view returns (uint256);
}

contract RedstoneAggregator is IAggregator {
    error ErrUnsafeUintToIntConversion();

    uint8 public constant decimals = 8;
    IRedstoneAdapter public immutable priceFeedAdapter;
    bytes32 public immutable dataFeedId;
    string public description;

    constructor(string memory _description, IRedstoneAdapter _priceFeedAdapter, bytes32 _dataFeedId) {
        description = _description;
        priceFeedAdapter = _priceFeedAdapter;
        dataFeedId = _dataFeedId;
    }

    function latestRoundData() public view override returns (uint80, int256, uint256, uint256, uint80) {
        return (0, latestAnswer(), 0, 0, 0);
    }

    function latestAnswer() public view override returns (int256) {
        uint256 uintAnswer = priceFeedAdapter.getValueForDataFeed(dataFeedId);

        if (uintAnswer > uint256(type(int256).max)) {
            revert ErrUnsafeUintToIntConversion();
        }

        return int256(uintAnswer);
    }
}
