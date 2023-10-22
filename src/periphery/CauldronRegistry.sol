// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";

contract CauldronRegistry is Owned {
    event LogCauldronAdded(bytes32 indexed key, string friendlyName, string friendlyDescription, address value, uint256 version);

    error ErrAlreadyExists();
    error ErrNotFound();
    error ErrInvalidRange();

    struct Cauldron {
        uint256 creationBlock;
        bool deprecated;
        string friendlyName;
        string friendlyDescription;
        address value;
        uint256 version;
    }

    mapping(bytes32 => Cauldron) public cauldrons;
    bytes32[] public cauldronKeys;

    constructor(address _owner) Owned(_owner) {}

    function add(string memory _friendlyName, string memory _friendlyDescription, address _value, uint256 _version) external onlyOwner {
        bytes32 key = keccak256(bytes(_friendlyName));
        if (cauldrons[key].value != address(0)) {
            revert ErrAlreadyExists();
        }

        Cauldron memory newCauldron = Cauldron({
            creationBlock: block.number,
            deprecated: false,
            friendlyName: _friendlyName,
            friendlyDescription: _friendlyDescription,
            value: _value,
            version: _version
        });

        cauldrons[key] = newCauldron;
        cauldronKeys.push(key);

        emit LogCauldronAdded(key, _friendlyName, _friendlyDescription, _value, _version);
    }

    function remove(bytes32 key) external onlyOwner {
        if (cauldrons[key].value == address(0)) {
            revert ErrNotFound();
        }

        // Delete from cauldrons mapping
        delete cauldrons[key];

        // Remove key from cauldronKeys array
        uint256 keyIndex = findKeyIndex(key);
        cauldronKeys[keyIndex] = cauldronKeys[cauldronKeys.length - 1];
        cauldronKeys.pop();
    }

    function get(bytes32 key) external view returns (Cauldron memory) {
        return cauldrons[key];
    }

    function findKeyIndex(bytes32 key) internal view returns (uint256) {
        for (uint256 i = 0; i < cauldronKeys.length; i++) {
            if (cauldronKeys[i] == key) {
                return i;
            }
        }
        revert ErrNotFound();
    }

    function getAll(uint256 startIndex, uint256 length) public view returns (Cauldron[] memory) {
        if (length == 0) {
            length = cauldronKeys.length - startIndex;
        }

        uint256 endIndex = startIndex + length;

        if (endIndex > cauldronKeys.length) {
            revert ErrInvalidRange();
        }

        Cauldron[] memory cauldronSlice = new Cauldron[](length);
        for (uint256 i = startIndex; i < endIndex; i++) {
            cauldronSlice[i - startIndex] = cauldrons[cauldronKeys[i]];
        }

        return cauldronSlice;
    }

    function getAll() external view returns (Cauldron[] memory) {
        return getAll(0, cauldronKeys.length);
    }

    function totals() external view returns (uint256) {
        return cauldronKeys.length;
    }
}
