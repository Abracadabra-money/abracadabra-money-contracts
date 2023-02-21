// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "periphery/Operatable.sol";

contract AbracadabraRegistry is Operatable {
    mapping(bytes32 => string) public entries;
    string[] public keys;

    error ErrKeyNotFound();

    function encodeKeyName(string memory key) public pure returns (bytes32) {
        return keccak256(abi.encode(key));
    }

    function get(string memory key) external view returns (string memory) {
        string memory entry = entries[encodeKeyName(key)];

        if (bytes(entry).length == 0) {
            revert ErrKeyNotFound();
        }

        return entry;
    }

    function set(string memory key, string memory value) external onlyOperators {
        entries[encodeKeyName(key)] = value;
        keys.push(key);
    }
}
