// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";

/// @title OperatableV2
/// @notice OperatableV2 is a contract that allows operator management.
/// The difference with OperatableV1 apart from using solmate `Owned` vs `BoringOwnable` is that
/// the constructor is taking in the owner except of using msg.sender.
/// This allows ensuring that the owner is right one.
/// For example, when deploying from a CREATE2 factory, the msg.sender would the factory address
/// which is usually not what we want.
contract OperatableV2 is Owned {
    event OperatorChanged(address indexed, bool);
    error NotAllowedOperator();

    mapping(address => bool) public operators;

    constructor(address _owner) Owned(_owner) {}

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
