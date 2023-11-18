// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
import {IOracle} from "interfaces/IOracle.sol";

/// @title ProxyOracle
/// @author 0xMerlin
/// @notice Oracle used for getting the price of an oracle implementation
contract ProxyOracle is IOracle, Owned {
    IOracle public oracleImplementation;

    event LogOracleImplementationChange(IOracle indexed oldOracle, IOracle indexed newOracle);

    constructor() Owned(msg.sender) {}

    function changeOracleImplementation(IOracle newOracle) external onlyOwner {
        IOracle oldOracle = oracleImplementation;
        oracleImplementation = newOracle;
        emit LogOracleImplementationChange(oldOracle, newOracle);
    }

    function decimals() external view returns (uint8) {
        return oracleImplementation.decimals();
    }

    // Get the latest exchange rate
    /// @inheritdoc IOracle
    function get(bytes calldata data) public override returns (bool, uint256) {
        return oracleImplementation.get(data);
    }

    // Check the last exchange rate without any state changes
    /// @inheritdoc IOracle
    function peek(bytes calldata data) public view override returns (bool, uint256) {
        return oracleImplementation.peek(data);
    }

    // Check the current spot exchange rate without any state changes
    /// @inheritdoc IOracle
    function peekSpot(bytes calldata data) external view override returns (uint256 rate) {
        return oracleImplementation.peekSpot(data);
    }

    /// @inheritdoc IOracle
    function name(bytes calldata) public pure override returns (string memory) {
        return "Proxy Oracle";
    }

    /// @inheritdoc IOracle
    function symbol(bytes calldata) public pure override returns (string memory) {
        return "Proxy";
    }
}
