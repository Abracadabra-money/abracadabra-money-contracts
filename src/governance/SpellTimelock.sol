// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";

contract SpellTimelock is TimelockControllerUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin) external initializer {
        __TimelockController_init(minDelay, proposers, executors, admin);
    }
}
