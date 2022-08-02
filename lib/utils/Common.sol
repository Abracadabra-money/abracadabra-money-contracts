// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Addresses.sol";

contract Common {
    Addresses internal immutable addresses = new Addresses();

    constructor() {}

    function getAddress(string memory key) public view returns (address) {
        return addresses.get(key);
    }
}
