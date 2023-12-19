// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IERC4626} from "interfaces/IERC4626.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {IGmxGlpManager} from "interfaces/IGmxV1.sol";

contract MagicGlpOracle is IOracle {
    IGmxGlpManager private immutable glpManager;
    IERC20 private immutable glp;
    IERC4626 public immutable magicGlp;

    constructor(IGmxGlpManager glpManager_, IERC20 glp_, IERC4626 magicGlp_) {
        glpManager = glpManager_;
        glp = glp_;
        magicGlp = magicGlp_;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function _get() internal view returns (uint256) {
        uint256 glpPrice = (uint256(glpManager.getAum(false)) / glp.totalSupply());
        return 1e30 / magicGlp.convertToAssets(glpPrice);
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
        return "MagicGlp USD Oracle";
    }

    /// @inheritdoc IOracle
    function symbol(bytes calldata) public pure override returns (string memory) {
        return "MagicGlp/USD";
    }
}
