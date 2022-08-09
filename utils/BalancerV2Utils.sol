// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library BalancerV2Utils {
    function decodeUserData(bytes calldata data) public pure returns (uint256, uint256[] memory) {
        return abi.decode(data, (uint256, uint256[]));
    }
}
