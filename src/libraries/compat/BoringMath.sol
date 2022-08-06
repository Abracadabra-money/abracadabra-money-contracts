// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

library BoringMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function to128(uint256 a) internal pure returns (uint128 c) {
        c = uint128(a);
    }

    function to64(uint256 a) internal pure returns (uint64 c) {
        c = uint64(a);
    }

    function to32(uint256 a) internal pure returns (uint32 c) {
        c = uint32(a);
    }
}

library BoringMath128 {
    function add(uint128 a, uint128 b) internal pure returns (uint128 c) {
        c = a + b;
    }

    function sub(uint128 a, uint128 b) internal pure returns (uint128 c) {
        c = a - b;
    }
}
