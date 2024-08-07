// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

/// @title OwnableOperators
/// @dev must call `_initializeOwner` to initialize owner
contract OwnableOperators {
    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event OperatorChanged(address indexed, bool);

    error Unauthorized();

    address public owner;
    mapping(address => bool) public operators;

    modifier onlyOwner() virtual {
        if(msg.sender != owner) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlyOperators() {
        if (!operators[msg.sender] && msg.sender != owner) {
            revert Unauthorized();
        }
        _;
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// Admin
    //////////////////////////////////////////////////////////////////////////////////////

    function setOperator(address operator, bool enable) external onlyOwner {
        operators[operator] = enable;
        emit OperatorChanged(operator, enable);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
        emit OwnershipTransferred(msg.sender, newOwner);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// Internals
    //////////////////////////////////////////////////////////////////////////////////////

    function _initializeOwner(address _owner) internal {
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }
}
