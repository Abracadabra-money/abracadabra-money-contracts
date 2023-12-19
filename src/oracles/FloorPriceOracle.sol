// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
import {MathLib} from "libraries/MathLib.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {IAggregator} from "interfaces/IAggregator.sol";

contract FloorPriceOracle is IOracle, Owned {
    IOracle public immutable oracle;
    uint256 public floor;
    bytes public oracleData;
    string public desc;

    constructor(string memory _desc, IOracle _oracle, bytes memory _oracleData, uint256 _floor) Owned(msg.sender) {
        desc = _desc;
        oracle = _oracle;
        oracleData = _oracleData;
        floor = _floor;
    }

    function decimals() external view returns (uint8) {
        return oracle.decimals();
    }

    function setFloor(uint256 _floor) public onlyOwner {
        floor = _floor;
    }

    function _get() internal view returns (uint256) {
        (, uint256 price) = oracle.peek(oracleData);
        return MathLib.min(floor, price);
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
