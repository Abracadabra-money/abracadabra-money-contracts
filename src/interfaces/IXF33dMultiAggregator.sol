// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IXF33dMultiAggregator {
    function decimals(bytes32 _feedHash) external view returns (uint8);

    function latestAnswer(bytes32 _feedHash) external view returns (int256);

    function latestRoundData(bytes32 _feedHash) external view returns (uint80, int256, uint256, uint256, uint80);
}
