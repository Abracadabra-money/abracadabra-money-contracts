/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity >=0.8.0;

interface IFeeRateImpl {
    function getFeeRate(address pool, address trader) external view returns (uint256);
}

interface IFeeRateModel {
    function getFeeRate(address trader) external view returns (uint256);
}
