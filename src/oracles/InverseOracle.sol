// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IOracle.sol";
import "interfaces/IAggregator.sol";

/// @title InverseOracle
/// @notice An oracle that inverts the price of an aggregator
contract InverseOracle is IOracle {
    IAggregator public immutable aggregator;
    uint256 public immutable decimalScale;

    string private desc;

    constructor(string memory _desc, IAggregator _aggregator) {
        aggregator = _aggregator;
        desc = _desc;
        decimalScale = 10 ** (_aggregator.decimals() * 2);
    }

    function decimals() external view returns (uint8) {
        return aggregator.decimals();
    }

    function _get() internal view returns (uint256) {
        return decimalScale / uint256(aggregator.latestAnswer());
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
