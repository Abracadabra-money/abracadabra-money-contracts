// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {Ownable} from "@solady/auth/Ownable.sol";
import {UUPSUpgradeable} from "@solady/utils/UUPSUpgradeable.sol";

contract SpellTimelock is TimelockControllerUpgradeable, Ownable, UUPSUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 _minDelay, address[] memory _proposers, address[] memory _executors, address _owner) external initializer {
        __TimelockController_init(_minDelay, _proposers, _executors, _owner);
        _initializeOwner(_owner);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Internals
    ////////////////////////////////////////////////////////////////////////////////

    function _authorizeUpgrade(address /*newImplementation*/) internal virtual override {
        _checkOwner();
    }
}
