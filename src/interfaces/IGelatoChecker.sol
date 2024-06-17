// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IGelatoChecker {
    function checker() external view returns (bool canExec, bytes memory execPayload);
}
