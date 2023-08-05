// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IOracle.sol";
import "interfaces/IYearnVault.sol";

interface ITriCryptoOracle {
    function lp_price() external view returns (uint256 price);
}

contract YearnTriCryptoOracle is IOracle {
    ITriCryptoOracle public constant LP_ORACLE = ITriCryptoOracle(0xAba04e7fe37fc3808d601DE4d65690E2889d7621);
    IYearnVault public immutable vault;

    constructor(address vault_) {
        vault = IYearnVault(vault_);
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    // Calculates the lastest exchange rate
    // Uses both divide and multiply only for tokens not supported directly by Chainlink, for example MKR/USD
    function _get() internal view returns (uint256) {
        return 1e54 / (LP_ORACLE.lp_price() * vault.pricePerShare());
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
        return "y3Crypto";
    }

    /// @inheritdoc IOracle
    function symbol(bytes calldata) public pure override returns (string memory) {
        return "y3Crypto";
    }
}
