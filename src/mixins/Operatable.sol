// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";

contract Operatable is BoringOwnable {
    event OperatorChanged(address indexed, bool);
    error NotAllowedOperator();

    mapping(address => bool) public operators;

    constructor() {}

    modifier onlyOperators() {
        if (!operators[msg.sender] && msg.sender != owner) {
            revert NotAllowedOperator();
        }
        _;
    }

    function setOperator(address operator, bool status) external onlyOwner {
        operators[operator] = status;
        emit OperatorChanged(operator, status);
    }
}
