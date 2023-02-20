// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "periphery/Operatable.sol";

contract Registry is Operatable {
    error ErrKeyNotFound();
    error ErrReservedBucketName();

    struct Entry {
        bytes32 key;
        bytes content;
        string encoding;
    }

    bytes32 public constant ALL_BUCKETNAME = keccak256(abi.encodePacked("*"));

    mapping(bytes32 => Entry) public entries;
    mapping(bytes32 => bytes32[]) public bucketKeys;
    mapping(bytes32 => mapping(bytes32 => bool)) public bucketEntryExists;

    function encodeKeyName(string memory key) external pure returns (bytes32) {
        return keccak256(abi.encode(key));
    }

    function get(bytes32 key) external view returns (Entry memory entry) {
        entry = entries[key];

        if (entry.content.length == 0) {
            revert ErrKeyNotFound();
        }

        return entry;
    }

    function getMany(bytes32 bucketName) external view returns (Entry[] memory bucketEntries) {
        return getMany(bucketName, type(uint256).max);
    }

    function getMany(bytes32 bucketName, uint256 maxSize) public view returns (Entry[] memory bucketEntries) {
        bytes32[] memory keys = bucketKeys[bucketName];
        bucketEntries = new Entry[](keys.length);
        for (uint256 i = 0; i < keys.length; ) {
            bucketEntries[i] = entries[keys[i]];

            if (--maxSize == 0) {
                break;
            }

            unchecked {
                ++i;
            }
        }
    }

    function getBucketSize(bytes32 bucketName) external view returns (uint256) {
        return bucketKeys[bucketName].length;
    }

    /// encoding is a string with a valid list of solidity types
    /// for example: "(uint256,bytes,bool)"
    function set(
        bytes32 key,
        bytes32 bucketName,
        bytes memory content,
        string memory encoding
    ) external onlyOperators {
        _set(key, bucketName, content, encoding);
    }

    function clearBucket(bytes32 bucketName) external onlyOperators {
        _validateBucketName(bucketName);

        bytes32[] memory keys = bucketKeys[bucketName];
        for (uint256 i = 0; i < keys.length; ) {
            bucketEntryExists[bucketName][keys[i]] = false;
            unchecked {
                ++i;
            }
        }

        delete bucketKeys[bucketName];
    }

    function removeFromBucket(bytes32 key, bytes32 bucketName) external onlyOperators {
        _validateBucketName(bucketName);
        _removeFromBucket(key, bucketName);
    }

    function removeFromBucket(bytes32[] memory keys, bytes32 bucketName) external onlyOperators {
        _validateBucketName(bucketName);

        for (uint256 i = 0; i < keys.length; ) {
            _removeFromBucket(keys[i], bucketName);
            unchecked {
                ++i;
            }
        }
    }

    function addToBucket(bytes32[] memory keys, bytes32 bucketName) external onlyOperators {
        _validateBucketName(bucketName);

        for (uint256 i = 0; i < keys.length; ) {
            _addToBucket(keys[i], bucketName);
            unchecked {
                ++i;
            }
        }
    }

    function setMany(
        bytes32[] memory keys,
        bytes[] memory contents,
        string memory encoding,
        bytes32 bucketName
    ) external onlyOperators {
        for (uint256 i = 0; i < keys.length; ) {
            _set(keys[i], bucketName, contents[i], encoding);
            unchecked {
                ++i;
            }
        }
    }

    function setMany(
        bytes32[] memory keys,
        bytes[] memory contents,
        string[] memory encodings,
        bytes32[] memory bucketNames
    ) external onlyOperators {
        for (uint256 i = 0; i < keys.length; ) {
            _set(keys[i], bucketNames[i], contents[i], encodings[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _set(
        bytes32 key,
        bytes32 bucketName,
        bytes memory content,
        string memory encoding
    ) private {
        Entry storage entry = entries[key];
        entry.key = key;
        entry.content = content;
        entry.encoding = encoding;

        if (bucketName != bytes32(0)) {
            _validateBucketName(bucketName);
            _addToBucket(key, bucketName);
        }

        // add to default bucket
        _addToBucket(key, ALL_BUCKETNAME);
    }

    function _addToBucket(bytes32 key, bytes32 bucketName) private {
        if (!bucketEntryExists[bucketName][key]) {
            bucketEntryExists[bucketName][key] = true;
            bucketKeys[bucketName].push(key);
        }
    }

    function _removeFromBucket(bytes32 key, bytes32 bucketName) private {
        if (bucketEntryExists[bucketName][key]) {
            bucketEntryExists[bucketName][key] = false;

            bytes32[] storage keys = bucketKeys[bucketName];

            for (uint256 i = 0; i < keys.length; ) {
                if (key == keys[i]) {
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

    function _validateBucketName(bytes32 bucketName) private pure {
        if (bucketName == ALL_BUCKETNAME) {
            revert ErrReservedBucketName();
        }
    }
}
