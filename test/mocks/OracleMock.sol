// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IAggregator.sol";
import "interfaces/IOracle.sol";

contract OracleMock is IOracle {
    int256 public price = 0;
    uint8 public _decimals = 18;

    function setPrice(int256 _price) public {
        price = _price;
    }

    function setDecimals(uint8 __decimals) public {
        _decimals = __decimals;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        return (0, price, 0, 0, 0);
    }

    function _get() internal view returns (uint256) {
        return 1e36 / uint256(price);
    }

    function get(bytes calldata) public view override returns (bool, uint256) {
        return (true, _get());
    }

    function peek(bytes calldata) public view override returns (bool, uint256) {
        return (true, _get());
    }

    function peekSpot(bytes calldata data) external view override returns (uint256 rate) {
        (, rate) = peek(data);
    }

    function name(bytes calldata) public pure override returns (string memory) {
        return "";
    }

    function symbol(bytes calldata) public pure override returns (string memory) {
        return "";
    }
}
