// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IFactory {
    function predictDeterministicAddress(
        address creator,
        address baseToken_,
        address quoteToken_,
        uint256 lpFeeRate_,
        uint256 i_,
        uint256 k_
    ) external view returns (address);

    function maintainerFeeRateModel() external view returns (address);

    function create(
        address baseToken_,
        address quoteToken_,
        uint256 lpFeeRate_,
        uint256 i_,
        uint256 k_,
        bool protocolOwnedPool_
    ) external returns (address clone);

    function poolExists(address pool) external view returns (bool);

    function addPool(address creator, address baseToken, address quoteToken, address pool) external;
}
