// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {OwnableOperators} from "/mixins/OwnableOperators.sol";

contract MyContract is OwnableOperators {
    constructor(address _owner) {
        _initializeOwner(_owner);
    }
}
