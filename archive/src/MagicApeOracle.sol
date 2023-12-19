// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IERC4626} from "interfaces/IERC4626.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {IGmxGlpManager} from "interfaces/IGmxGlpManager.sol";
import {IAggregator} from "interfaces/IAggregator.sol";

contract MagicApeOracle is IOracle {
    IERC4626 public immutable magicApe;
    IAggregator public immutable apeUsd;

    constructor(IERC4626 _magicApe, IAggregator _apeUsd) {
        magicApe = _magicApe;
        apeUsd = _apeUsd;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function _get() internal view returns (uint256) {
        return 1e26 / magicApe.convertToAssets(uint256(apeUsd.latestAnswer()));
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
    function name(bytes calldata) public pure override returns (string memory) {
        return "MagicApe USD Oracle";
    }

    /// @inheritdoc IOracle
    function symbol(bytes calldata) public pure override returns (string memory) {
        return "MagicApe/USD";
    }
}
