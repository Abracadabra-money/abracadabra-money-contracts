// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ILzApp {
    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) external;

    function minDstGasLookup(uint16 _srcChainId, uint16 _dstChainId) external view returns (uint);
}
