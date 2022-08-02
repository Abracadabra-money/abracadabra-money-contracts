// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Contract {
    address public owner;
    address public immutable mim;

    constructor(address _mim) {
        owner = msg.sender;
        mim = _mim;
    }

    function setOwner(address newOwner) public {
        require(msg.sender == owner, "not owner");
        owner = newOwner;
    }
}
