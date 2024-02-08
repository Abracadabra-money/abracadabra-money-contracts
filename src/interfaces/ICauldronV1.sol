// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IOracle} from "interfaces/IOracle.sol";

interface ICauldronV1 {
    function accrue() external;

    function withdrawFees() external;

    function accrueInfo() external view returns (uint64, uint128);

    function setFeeTo(address newFeeTo) external;

    function feeTo() external view returns (address);

    function masterContract() external view returns (ICauldronV1);

    function bentoBox() external view returns (address);

    function exchangeRate() external view returns (uint256 rate);

    function updateExchangeRate() external returns (bool updated, uint256 rate);

    function oracle() external view returns (IOracle);

    function oracleData() external view returns (bytes memory);
}
