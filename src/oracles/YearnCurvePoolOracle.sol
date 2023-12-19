// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IOracle} from "interfaces/IOracle.sol";
import {ICurveStablePoolAggregator} from "interfaces/ICurveStablePoolAggregator.sol";
import {IYearnVault} from "interfaces/IYearnVault.sol";
import {ICurvePool} from "interfaces/ICurvePool.sol";

/// @notice Yearn oracle version using CurveStablePoolAggregator
contract YearnCurvePoolOracle is IOracle {
    ICurveStablePoolAggregator public immutable aggregator;
    IYearnVault public immutable vault;
    uint256 public immutable decimalScale;
    string private desc;

    constructor(IYearnVault _vault, ICurveStablePoolAggregator _aggregator, string memory _desc) {
        assert(_vault.token() == _aggregator.curvePool());
        assert(_vault.decimals() == _aggregator.decimals());

        vault = _vault;
        aggregator = _aggregator;
        desc = _desc;

        decimalScale = 10 ** (_aggregator.decimals() + (vault.decimals() * 2));
    }

    function decimals() external view returns (uint8) {
        return uint8(vault.decimals());
    }

    function _get() internal view returns (uint256) {
        return decimalScale / (uint256(aggregator.latestAnswer()) * vault.pricePerShare());
    }

    /// @inheritdoc IOracle
    function get(bytes calldata) public view override returns (bool, uint256) {
        return (true, _get());
    }

    /// @inheritdoc IOracle
    function peek(bytes calldata) public view override returns (bool, uint256) {
        return (true, _get());
    }

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
