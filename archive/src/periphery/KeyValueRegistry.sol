// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "periphery/Operatable.sol";

contract KeyValueRegistry is Operatable {
    error ErrInvalidKeyName(string);
    error ErrKeyNotFound(string);
    event LogKeySet(string, string);
    event LogKeyRemove(string);

    mapping(string => string) public dict;
    mapping(string => bool) public keyExists;
    string[] public keys;

    constructor(address _owner) {
        if (msg.sender != _owner) {
            operators[msg.sender] = false;
            operators[_owner] = true;
            transferOwnership(_owner, true, false);
        }
    }

    function set(string memory key, string memory value) external onlyOperators {
        if (bytes(key).length == 0) {
            revert ErrInvalidKeyName(key);
        }

        if (!keyExists[key]) {
            keyExists[key] = true;
            keys.push(key);
        }

        dict[key] = value;
    }

    function get(string memory key) public view returns (string memory) {
        if (!keyExists[key]) {
            revert ErrKeyNotFound(key);
        }
        return dict[key];
    }

    function get(string[] memory _keys) external view returns (string[] memory values) {
        values = new string[](_keys.length);

        for (uint256 i = 0; i < _keys.length; ) {
            values[i] = get(_keys[i]);
            unchecked {
                ++i;
            }
        }
    }

    function remove(string memory keyNeedle) external onlyOperators {
        if (!keyExists[keyNeedle]) {
            revert ErrKeyNotFound(keyNeedle);
        }
        for (uint256 i = 0; i < keys.length; ) {
            string memory key = keys[i];
            if (keccak256(abi.encode(keys[i])) == keccak256(abi.encode(keyNeedle))) {
                dict[key] = "";
                keyExists[key] = false;
                keys[i] = keys[keys.length - 1];
                keys.pop();
                return;
            }
            unchecked {
                ++i;
            }
        }
    }
}
