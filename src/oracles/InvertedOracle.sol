// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IOracle.sol";
import "interfaces/IAggregator.sol";

contract InvertedOracle is IOracle {
    IAggregator public immutable denominatorOracle;
    IAggregator public immutable oracle;
    string private desc;

    constructor(
        IAggregator _oracle,
        IAggregator _denominatorOracle,
        string memory _desc
    ) {
        oracle = _oracle;
        denominatorOracle = _denominatorOracle;
        desc = _desc;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function _get() internal view returns (uint256) {
        uint256 priceFeed = uint256(oracle.latestAnswer()) * uint256(denominatorOracle.latestAnswer());
        return (1e18 + 10**oracle.decimals() + 10**denominatorOracle.decimals()) / priceFeed;
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
