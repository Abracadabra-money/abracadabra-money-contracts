// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IUmbrellaFeeds {
    struct PriceData {
        uint8 data;
        uint24 heartbeat;
        uint32 timestamp;
        uint128 price;
    }

    function DECIMALS() external view returns (uint8);

    function getChainId() external view returns (uint256 id);

    function getManyPriceData(bytes32[] memory _keys) external view returns (PriceData[] memory data);

    function getManyPriceDataRaw(bytes32[] memory _keys) external view returns (PriceData[] memory data);

    function getName() external pure returns (bytes32);

    function getPrice(bytes32 _key) external view returns (uint128 price);

    function getPriceData(bytes32 _key) external view returns (PriceData memory data);

    function getPriceDataByName(string memory _name) external view returns (PriceData memory data);
}
