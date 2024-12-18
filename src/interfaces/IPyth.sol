// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IPyth {
    struct PriceInfo {
        int64 price;
        uint64 conf;
        int32 expo;
        uint256 publishTime;
    }

    function getPriceNoOlderThan(bytes32 id, uint256 age) external view returns (PriceInfo memory priceInfo);
    function getPrice(bytes32 id) external view returns (PriceInfo memory priceInfo);
}
