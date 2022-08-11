// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

interface IVaultHarvester {
    function harvest(address recipient) external;
}