// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IOracle} from "interfaces/IOracle.sol";
import {IAggregator} from "interfaces/IAggregator.sol";

contract ChainlinkOracle is IOracle {
    IAggregator public immutable aggregator;
    uint256 public immutable decimalScale;
    uint8 public immutable decimals;
    string private desc;

    /// @notice Uses chainlink aggregator with optional upscaling decimals
    /// @param _desc A description of the oracle
    /// @param _aggregator The aggregator to use
    /// @param _upscaledTargetDecimals The number of decimals to return, 0 to use the aggregator's decimals
    constructor(string memory _desc, IAggregator _aggregator, uint8 _upscaledTargetDecimals) {
        aggregator = _aggregator;
        desc = _desc;

        uint8 aggregatorDecimals = _aggregator.decimals();

        decimals = _upscaledTargetDecimals > aggregatorDecimals ? _upscaledTargetDecimals : aggregatorDecimals;
        decimalScale = _upscaledTargetDecimals > aggregatorDecimals ? 10 ** (_upscaledTargetDecimals - aggregatorDecimals) : 1;
    }

    function _get() internal view returns (uint256) {
        return uint256(aggregator.latestAnswer()) * decimalScale;
    }

    // Get the latest exchange rate
    /// @inheritdoc IOracle
    function get(bytes calldata) public view override returns (bool, uint256) {
        return (true, _get());
    }

    // Check the last exchange rate without any state changes
    /// @inheritdoc IOracle
    function peek(bytes calldata) public view override returns (bool, uint256) {
        return (true, _get());
    }

    // Check the current spot exchange rate without any state changes
    /// @inheritdoc IOracle
    function peekSpot(bytes calldata data) external view override returns (uint256 rate) {
        (, rate) = peek(data);
    }

    /// @inheritdoc IOracle
    function name(bytes calldata) public view override returns (string memory) {
        return desc;
    }

    /// @inheritdoc IOracle
    function symbol(bytes calldata) public view override returns (string memory) {
        return desc;
    }
}
