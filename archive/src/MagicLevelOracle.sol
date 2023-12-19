// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/IERC4626.sol";
import "interfaces/IOracle.sol";
import "interfaces/ILevelFinanceLiquidityPool.sol";

contract MagicLevelOracle is IOracle {
    using BoringERC20 for IERC20;

    IERC4626 public immutable trancheVault;
    IERC20 public immutable tranche;
    ILevelFinanceLiquidityPool public immutable liquidityPool;

    constructor(IERC4626 _trancheVault, ILevelFinanceLiquidityPool _liquidityPool) {
        trancheVault = _trancheVault;
        liquidityPool = _liquidityPool;
        tranche = _trancheVault.asset();
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function _get() internal view returns (uint256) {
        uint256 lpPrice = liquidityPool.getTrancheValue(address(tranche), true) / tranche.totalSupply();
        return 1e30 / trancheVault.convertToAssets(lpPrice);
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
        return "MagicLevel USD Oracle";
    }

    /// @inheritdoc IOracle
    function symbol(bytes calldata) public pure override returns (string memory) {
        return "MagicLevel/USD";
    }
}
