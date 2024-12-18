// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IOracle} from "/interfaces/IOracle.sol";

interface IPyth {
    struct PriceInfo {
        int64 price;
        uint64 conf;
        int32 expo;
        uint256 publishTime;
    }

    function getPriceNoOlderThan(bytes32 id, uint256 age) external view returns (PriceInfo memory priceInfo);
}

contract PythOracle is IOracle {
    uint8 public constant decimals = 18;

    IPyth public immutable pyth;
    uint256 public immutable maxAge;

    constructor(IPyth _pyth, uint256 _maxAge) {
        pyth = _pyth;
        maxAge = _maxAge;
    }

    function _get(bytes calldata data) internal view returns (uint256) {
        bytes32 feedId = abi.decode(data, (bytes32));
        IPyth.PriceInfo memory priceInfo = pyth.getPriceNoOlderThan(feedId, maxAge);
        return 10 ** (18 + uint8(int8(-priceInfo.expo))) / uint256(uint64(priceInfo.price));
    }

    function get(bytes calldata data) external view override returns (bool success, uint256 rate) {
        return (true, _get(data));
    }

    function peek(bytes calldata data) external view override returns (bool success, uint256 rate) {
        return (true, _get(data));
    }

    function peekSpot(bytes calldata data) external view override returns (uint256 rate) {
        return _get(data);
    }

    function symbol(bytes calldata) external pure override returns (string memory) {
        return "Pyth Oracle";
    }

    function name(bytes calldata) external pure override returns (string memory) {
        return "Pyth Oracle";
    }
}
