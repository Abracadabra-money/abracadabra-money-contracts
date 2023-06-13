// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ILzApp {
    function minDstGasLookup(uint16 _srcChainId, uint16 _dstChainId) external view returns (uint);
}
