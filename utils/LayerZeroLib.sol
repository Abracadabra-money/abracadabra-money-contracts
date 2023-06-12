// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library LayerZeroLib {
    function getRecipient(address remote, address local) internal pure returns (bytes memory) {
        return abi.encodePacked(remote, local);
    }
}
