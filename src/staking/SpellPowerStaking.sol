// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@solady/utils/UUPSUpgradeable.sol";
import {MultiRewards} from "/staking/MultiRewards.sol";

contract SpellPowerStaking is MultiRewards, UUPSUpgradeable, Initializable {
    event LockupPeriodUpdated(uint256 lockupPeriod);

    error ErrLockedUp();

    uint256 public lockupPeriod;

    mapping(address user => uint256 timestamp) public lastAdded;

    constructor(address _stakingToken) MultiRewards(_stakingToken, address(0)) {
        _disableInitializers();
    }

    function initialize(address _owner) external initializer {
        _initializeOwner(_owner);
    }

    function stake(uint256 amount) public virtual override whenNotPaused {
        super.stake(amount);
        lastAdded[msg.sender] = block.timestamp;
    }

    function withdraw(uint256 amount) public virtual override {
        _checkLockup(msg.sender);
        super.withdraw(amount);
    }

    //////////////////////////////////////////////////////////////////////////////////
    // Admin
    //////////////////////////////////////////////////////////////////////////////////

    function setLockupPeriod(uint256 _lockupPeriod) external onlyOwner {
        lockupPeriod = _lockupPeriod;
        emit LockupPeriodUpdated(_lockupPeriod);
    }

    //////////////////////////////////////////////////////////////////////////////////
    // Internals
    //////////////////////////////////////////////////////////////////////////////////

    function _checkLockup(address user) internal view {
        if (lastAdded[user] + lockupPeriod > block.timestamp) {
            revert ErrLockedUp();
        }
    }

    function _authorizeUpgrade(address /*newImplementation*/) internal virtual override {
        _checkOwner();
    }
}
