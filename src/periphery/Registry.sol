// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "periphery/Operatable.sol";

contract Registry is Operatable {
    error ErrKeyNotFound(string key);
    error ErrBucketNotFound(string bucketName);

    struct Entry {
        bytes data;
        string encoding;
        string[] buckets;
    }

    mapping(string => Entry) private _entries;
    mapping(string => string[]) private _bucketKeys;
    mapping(string => mapping(string => bool)) private _bucketEntryExists;

    /// encoding is a string with a valid list of solidity types
    /// for example: "uint256,bytes,bool"
    function set(
        string memory key,
        bytes memory data,
        string memory encoding,
        string memory bucketName
    ) external onlyOperators {
        Entry storage entry = _entries[key];
        entry.data = data;
        entry.encoding = encoding;

        if (bytes(bucketName).length != 0 && !_bucketEntryExists[bucketName][key]) {
            _bucketEntryExists[bucketName][key] = true;
            _bucketKeys[bucketName].push(key);
            _entries[key].buckets.push(bucketName);
        }
    }

    function get(string memory key) external view returns (Entry memory entry) {
        entry = _entries[key];

        if (entry.data.length == 0) {
            revert ErrKeyNotFound(key);
        }

        return entry;
    }

    function getMany(string memory bucketName) external view returns (Entry[] memory entries) {
        string[] memory keys = _bucketKeys[bucketName];
        entries = new Entry[](keys.length);
        for (uint256 i = 0; i < keys.length; ) {
            entries[i] = _entries[keys[i]];
            unchecked {
                ++i;
            }
        }
    }

    /// remove a key and referenced buckets (gas expensive)
    function remove(string memory key) external onlyOperators {
        // Remove key from referenced buckets
        string[] storage referencedBuckets = _entries[key].buckets;
        for (uint256 i = 0; i < referencedBuckets.length; ) {
            string storage bucketName = referencedBuckets[i];
            string[] storage bucketKeys = _bucketKeys[bucketName];

            for (uint256 j = 0; j < bucketKeys.length; ) {
                // remove key from bucket
                if (keccak256(abi.encodePacked(bucketKeys[j])) == keccak256(abi.encodePacked(key))) {
                    bucketKeys[j] = bucketKeys[bucketKeys.length - 1];
                    bucketKeys.pop();
                    break;
                }

                unchecked {
                    ++j;
                }
            }

            _bucketEntryExists[bucketName][key] = false;
            unchecked {
                ++i;
            }
        }

        delete _entries[key];
    }
}
