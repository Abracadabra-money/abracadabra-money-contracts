// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @title OperatableV3
/// @notice Same as OperatableV2 but without taking care of the Ownable part.
/// This is useful when the contract inheriting this is already inheriting from Owned.
abstract contract OperatableV3 {
    event LogOperatorChanged(address indexed, bool);

    error ErrNotAllowedOperator();
    error ErrNotOwner();

    mapping(address => bool) public operators;

    constructor() {}

    modifier onlyOperators() {
        if (!operators[msg.sender] && !_isOwner(msg.sender)) {
            revert ErrNotAllowedOperator();
        }
        _;
    }

    function setOperator(address operator, bool status) external {
        if (!_isOwner(msg.sender)) {
            revert ErrNotOwner();
        }

        operators[operator] = status;
        emit LogOperatorChanged(operator, status);
    }

    function _isOwner(address _account) internal view virtual returns (bool);
}
