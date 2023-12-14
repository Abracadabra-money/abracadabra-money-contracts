// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IMimCauldronDistributor {
    function cauldronInfos(uint256)
        external
        view
        returns (
            address cauldron,
            uint256 targetApyPerSecond,
            uint64 lastDistribution,
            address oracle,
            bytes memory oracleData,
            address degenBox,
            address collateral,
            uint256 minTotalBorrowElastic
        );

    function distribute() external;

    function feeCollector() external view returns (address);

    function feePercent() external view returns (uint8);

    function getCauldronInfoCount() external view returns (uint256);

    function paused() external view returns (bool);

    function setCauldronParameters(
        address _cauldron,
        uint256 _targetApyBips,
        uint256 _minTotalBorrowElastic
    ) external;

    function setFeeParameters(address _feeCollector, uint8 _feePercent) external;

    function setPaused(bool _paused) external;

    function withdraw() external;
}
