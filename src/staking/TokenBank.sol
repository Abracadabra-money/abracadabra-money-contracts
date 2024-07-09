// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Pausable} from "openzeppelin-contracts/utils/Pausable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";
import {IMintableBurnable} from "interfaces/IMintableBurnable.sol";
import {MathLib} from "libraries/MathLib.sol";

/// @notice Allows to mint 1:1 backed tokenA for tokenB
/// To redeem back tokenB, the user must burn tokenA
/// and wait for the locking period to expire
contract TokenBank is OperatableV2, Pausable {
    using SafeTransferLib for address;

    event LogDeposit(address indexed user, uint256 amount, uint256 unlockTime, uint256 lockCount);
    event LogClaimed(address indexed user, uint256 amount);

    error ErrZeroAmount();
    error ErrMaxUserLocksExceeded();
    error ErrInvalidLockDuration();
    error ErrExpired();
    error ErrInvalidDurationRatio();

    struct LockedBalance {
        uint256 amount;
        uint256 unlockTime;
    }

    uint256 public constant EPOCH_DURATION = 1 weeks;
    uint256 public constant MIN_LOCK_DURATION = 1 weeks;

    uint256 public immutable lockDuration;
    uint256 public immutable maxLocks;
    address public immutable asset;
    address public immutable underlyingToken;

    mapping(address user => LockedBalance[] locks) internal _userLocks;
    mapping(address user => uint256 index) public lastLockIndex;

    constructor(address _asset, address _underlyingToken, uint256 _lockDuration, address _owner) OperatableV2(_owner) {
        if (_lockDuration < MIN_LOCK_DURATION) {
            revert ErrInvalidLockDuration();
        }

        asset = _asset;
        underlyingToken = _underlyingToken;

        if (_lockDuration % EPOCH_DURATION != 0) {
            revert ErrInvalidDurationRatio();
        }

        lockDuration = _lockDuration;
        maxLocks = (_lockDuration / EPOCH_DURATION) + 1;
    }

    function deposit(uint256 amount, uint256 lockingDeadline) public whenNotPaused returns (uint256 claimable) {
        if (amount == 0) {
            revert ErrZeroAmount();
        }

        IMintableBurnable(asset).burn(msg.sender, amount);

        claimable = claim();
        _createLock(msg.sender, amount, lockingDeadline);
    }

    function claim() public whenNotPaused returns (uint256 claimable) {
        claimable = _releaseLocks(msg.sender);

        if (claimable > 0) {
            underlyingToken.safeTransfer(msg.sender, claimable);
            emit LogClaimed(msg.sender, claimable);
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////////////

    function balances(address user) external view returns (uint256 locked, uint256 unlocked) {
        for (uint256 i = 0; i < _userLocks[user].length; i++) {
            LockedBalance memory lock = _userLocks[user][i];
            if (lock.unlockTime <= block.timestamp) {
                unlocked += lock.amount;
                continue;
            }

            locked += lock.amount;
        }
    }

    function userLocks(address user) external view returns (LockedBalance[] memory) {
        return _userLocks[user];
    }

    function userLocksLength(address user) external view returns (uint256) {
        return _userLocks[user].length;
    }

    function nextUnlockTime() public view returns (uint256) {
        return nextEpoch() + lockDuration;
    }

    function epoch() public view returns (uint256) {
        return (block.timestamp / EPOCH_DURATION) * EPOCH_DURATION;
    }

    function nextEpoch() public view returns (uint256) {
        return epoch() + EPOCH_DURATION;
    }

    function remainingEpochTime() public view returns (uint256) {
        return nextEpoch() - block.timestamp;
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////////////

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS
    //////////////////////////////////////////////////////////////////////////////////////////////

    function mint(uint256 amount, address to) external onlyOperators {
        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);
        IMintableBurnable(asset).mint(to, amount);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////////////

    function _releaseLocks(address user) internal returns (uint256 claimable) {
        uint256 length = _userLocks[user].length;

        for (uint256 i = length; i > 0; i--) {
            uint256 index = i - 1;
            LockedBalance memory lock = _userLocks[user][index];

            if (lock.unlockTime <= block.timestamp) {
                claimable += lock.amount;
                uint256 lastIndex = _userLocks[user].length - 1;

                if (index != lastIndex) {
                    _userLocks[user][index] = _userLocks[user][lastIndex];

                    if (lastLockIndex[user] == lastIndex) {
                        lastLockIndex[user] = index;
                    }
                }

                _userLocks[user].pop();
            }
        }
    }

    function _createLock(address user, uint256 amount, uint256 lockingDeadline) internal {
        if (lockingDeadline < block.timestamp) {
            revert ErrExpired();
        }

        uint256 _nextUnlockTime = nextUnlockTime();
        uint256 _lastLockIndex = lastLockIndex[user];
        uint256 lockCount = _userLocks[user].length;

        // Add to current lock if it's the same unlock time or the first one
        // userLocks is sorted by unlockTime, so the last lock is the most recent one
        if (lockCount == 0 || _userLocks[user][_lastLockIndex].unlockTime < _nextUnlockTime) {
            // Limit the number of locks per user to avoid too much gas costs per user
            // when looping through the locks
            if (lockCount == maxLocks) {
                revert ErrMaxUserLocksExceeded();
            }

            _userLocks[user].push(LockedBalance({amount: amount, unlockTime: _nextUnlockTime}));
            lastLockIndex[user] = lockCount;

            unchecked {
                ++lockCount;
            }
        }
        /// It's the same reward period, so we just add the amount to the current lock
        else {
            _userLocks[user][_lastLockIndex].amount += amount;
        }

        emit LogDeposit(user, amount, _nextUnlockTime, lockCount);
    }
}
