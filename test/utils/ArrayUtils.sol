// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract ArrayUtils {
    mapping (address => bool) public __uniqueAddresses;

    function uniquify(address[] memory input) public returns (address[] memory ret) {
        uint uniqueCount;

        for(uint256 i = 0; i < input.length; i++) {
            if (!__uniqueAddresses[input[i]]) {
                __uniqueAddresses[input[i]] = true;
                uniqueCount++;
            }
        }

        ret = new address[](uniqueCount);
        uint index = 0;
        for(uint256 i = 0; i < input.length; i++) {
            if (__uniqueAddresses[input[i]]) {
                ret[index] = input[i];
                index++;
                __uniqueAddresses[input[i]] = false;
            }
        }
    }
}
