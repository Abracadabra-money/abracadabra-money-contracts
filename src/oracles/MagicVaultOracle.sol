// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IERC4626} from "interfaces/IERC4626.sol";
import {IAggregator} from "interfaces/IAggregator.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {IGmxGlpManager} from "interfaces/IGmxV1.sol";

contract MagicVaultOracle is IOracle {
    IERC4626 public immutable vault;
    IAggregator public immutable aggregator;
    uint256 public immutable decimalScale;
    string private desc;

    /// @notice Magic vault oracle
    /// @param _desc The description of the oracle
    /// @param _vault The vault to use
    /// @param _aggregator The aggregator to use for the asset.
    constructor(string memory _desc, IERC4626 _vault, IAggregator _aggregator) {
        assert(_vault.decimals() == _aggregator.decimals());
        desc = _desc;
        vault = _vault;
        aggregator = _aggregator;
        decimalScale = 10 ** (_vault.decimals() * 2);
    }

    function decimals() external view returns (uint8) {
        return vault.decimals();
    }

    function _get() internal view returns (uint256) {
        return decimalScale / vault.convertToAssets(uint256(aggregator.latestAnswer()));
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
