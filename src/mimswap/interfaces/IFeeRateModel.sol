/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity >=0.8.0;

interface IFeeRateImpl {
    function getFeeRate(
        address pool,
        address trader,
        uint256 lpFeeRate
    ) external view returns (uint256 adjustedLpFeeRate, uint256 mtFeeRate);
}

interface IFeeRateModel {
    function maintainer() external view returns (address);

    function getFeeRate(address trader, uint256 lpFeeRate) external view returns (uint256 adjustedLpFeeRate, uint256 mtFeeRate);
}
