// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IOracle.sol";
import "interfaces/IGmxGlpManager.sol";
import "BoringSolidity/interfaces/IERC20.sol";

contract GLPOracle is IOracle {
    IGmxGlpManager immutable private glpManager;
    IERC20 immutable private glp;
    constructor(
        IGmxGlpManager glpManager_,
        IERC20 glp_
    ) {
        glpManager = glpManager_;
        glp = glp_;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function _get() internal view returns (uint256) {
        return 30 / uint256(glpManager.getAum(false)) / glp.totalSupply();
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
        return "GLP USD Oracle";
    }

    /// @inheritdoc IOracle
    function symbol(bytes calldata) public pure override returns (string memory) {
        return "GLP/USD";
    }
}
