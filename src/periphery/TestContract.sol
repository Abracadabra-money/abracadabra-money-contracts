// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "mixins/OperatableV2.sol";

contract TestContract is OperatableV2 {
    constructor(address _owner) OperatableV2(_owner) {}
}
