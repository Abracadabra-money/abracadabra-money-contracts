// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
import {IOracle} from "interfaces/IOracle.sol";

contract FixedPriceOracle is IOracle, Owned {
    event LogPriceChanged(uint256 price);

    uint8 public immutable decimals;
    uint256 public price;
    string public desc;

    constructor(string memory _desc, uint256 _price, uint8 _decimals) Owned(msg.sender) {
        desc = _desc;
        price = _price;
        decimals = _decimals;
    }

    function setPrice(uint256 _price) public onlyOwner {
        price = _price;
        emit LogPriceChanged(_price);
    }

    function _get() internal view returns (uint256) {
        return price;
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