// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {OperatableV2} from "mixins/OperatableV2.sol";
import {Pausable} from "openzeppelin-contracts/security/Pausable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {MathLib} from "libraries/MathLib.sol";

/// @notice A staking contract that distributes multiple rewards to stakers.
/// Stakers can lock their tokens for a period of time to get a boost on their rewards.
/// @author Based from Curve Finance's MultiRewards contract https://github.com/curvefi/multi-rewards/blob/master/contracts/MultiRewards.sol
/// @author Based from Ellipsis Finance's EpsStaker https://github.com/ellipsis-finance/ellipsis/blob/master/contracts/EpsStaker.sol
/// @author Based from Convex Finance's CvxLockerV2 https://github.com/convex-eth/platform/blob/main/contracts/contracts/CvxLockerV2.sol
contract LockingMultiRewards is OperatableV2, Pausable {
    using SafeTransferLib for address;

    event LogRewardAdded(uint256 reward);
    event LogStaked(address indexed user, uint256 amount);
    event LogLocked(address indexed user, uint256 amount, uint256 unlockTime, uint256 lockCount);
    event LogUnlocked(address indexed user, uint256 amount, uint256 index);
    event LogLockIndexChanged(address indexed user, uint256 fromIndex, uint256 toIndex);
    event LogWithdrawn(address indexed user, uint256 amount);
    event LogRewardPaid(address indexed user, address indexed rewardsToken, uint256 reward);
    event LogRewardsDurationUpdated(address token, uint256 newDuration);
    event LogRecovered(address token, uint256 amount);
    event LogSetMinLockAmount(uint256 previous, uint256 current);

    error ErrZeroAmount();
    error ErrInvalidTokenAddress();
    error ErrMaxUserLocksExceeded();
    error ErrNotExpired();
    error ErrInvalidUser();
    error ErrLockAmountTooSmall();
    error ErrLengthMismatch();
    error ErrNoLocks();
    error ErrLockNotExpired();
    error ErrMaxRewardsExceeded();

    struct Reward {
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    struct Balances {
        uint256 unlocked;
        uint256 locked;
    }

    struct LockedBalance {
        uint256 amount;
        uint256 unlockTime;
    }

    uint256 private constant BIPS = 10_000;
    uint256 private constant MAX_NUM_REWARDS = 5;

    uint256 public immutable maxLocks;
    uint256 public immutable lockingBoostMultiplerInBips;
    uint256 public immutable rewardsDuration;
    uint256 public immutable lockDuration;
    address public immutable stakingToken;

    mapping(address token => Reward info) private _rewardData;
    mapping(address user => Balances balances) private _balances;
    mapping(address user => LockedBalance[] locks) private _userLocks;

    mapping(address user => mapping(address token => uint256 amount)) public userRewardPerTokenPaid;
    mapping(address user => mapping(address token => uint256 amount)) public rewards;
    mapping(address user => uint256 index) public lastLockIndex;

    address[] public rewardTokens;

    uint256 public lockedSupply; // all locked boosted deposits
    uint256 public unlockedSupply; // all unlocked unboosted deposits
    uint256 public minLockAmount; // minimum amount allowed to lock

    ///
    /// @dev Constructor
    /// @param _stakingToken The token that is being staked
    /// @param _owner The owner of the contract
    /// @param _lockingBoostMultiplerInBips The multiplier for the locking boost. 30000 means if you stake 100, you get 300 locked
    /// @param _rewardsDuration The duration of the rewards period in seconds, should be 7 days by default.
    /// @param _lockDuration The duration of the lock period in seconds, should be 13 weeks by default.
    constructor(
        address _stakingToken,
        uint256 _lockingBoostMultiplerInBips,
        uint256 _rewardsDuration,
        uint256 _lockDuration,
        address _owner
    ) OperatableV2(_owner) {
        stakingToken = _stakingToken;
        lockingBoostMultiplerInBips = _lockingBoostMultiplerInBips;
        rewardsDuration = _rewardsDuration;
        lockDuration = _lockDuration;

        // kocks are combined into the same `rewardsDuration` epoch. So, if
        // a user stake with locking every `rewardsDuration` this should reach the
        // maximum number of possible simultaneous because the first lock gets expired,
        // freeing up a slot.
        maxLocks = _lockDuration / _rewardsDuration;
    }

    /// @notice Stakes the given amount of tokens for the given user.
    /// @param amount The amount of tokens to stake
    /// @param lock_ If true, the tokens will be locked for the lock duration for a reward boost
    function stake(uint256 amount, bool lock_) public whenNotPaused {
        if (amount == 0) {
            revert ErrZeroAmount();
        }

        // This staking contract isn't using balanceOf, so it's safe to transfer immediately
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        _updateRewardsForUser(msg.sender);

        if (lock_) {
            _createLock(msg.sender, amount);
        } else {
            _balances[msg.sender].unlocked += amount;
            unlockedSupply += amount;

            emit LogStaked(msg.sender, amount);
        }
    }

    /// @notice Locks an existing unlocked balance.
    function lock(uint256 amount) public whenNotPaused {
        if (amount == 0) {
            revert ErrZeroAmount();
        }

        _updateRewardsForUser(msg.sender);

        _balances[msg.sender].unlocked -= amount;
        unlockedSupply -= amount;

        _createLock(msg.sender, amount);
    }

    /// @notice Withdraws the given amount of tokens for the given user.
    /// Will use the unlocked balance first, then iterate through the locks to find
    /// expired locks, prunning them and cumulate the amounts to withdraw.
    /// @param amount The amount of tokens to withdraw
    function withdraw(uint256 amount) public virtual {
        if (amount == 0) {
            revert ErrZeroAmount();
        }

        _updateRewardsForUser(msg.sender);

        _balances[msg.sender].unlocked -= amount;
        unlockedSupply -= amount;

        stakingToken.safeTransfer(msg.sender, amount);
        emit LogWithdrawn(msg.sender, amount);
    }

    function withdrawWithRewards(uint256 amount) public virtual {
        withdraw(amount);
        _getRewards();
    }

    function getRewards() public virtual {
        _updateRewardsForUser(msg.sender);
        _getRewards();
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////////////
    function rewardData(address token) external view returns (Reward memory) {
        return _rewardData[token];
    }

    function rewardsForDuration(address rewardToken) external view returns (uint256) {
        return _rewardData[rewardToken].rewardRate * rewardsDuration;
    }

    function rewardTokensLength() external view returns (uint256) {
        return rewardTokens.length;
    }

    function balances(address user) external view returns (Balances memory) {
        return _balances[user];
    }

    function userLocks(address user) external view returns (LockedBalance[] memory) {
        return _userLocks[user];
    }

    function userLocksLength(address user) external view returns (uint256) {
        return _userLocks[user].length;
    }

    function locked(address user) external view returns (uint256) {
        return _balances[user].locked;
    }

    function unlocked(address user) external view returns (uint256) {
        return _balances[user].unlocked;
    }

    function totalSupply() public view returns (uint256) {
        return unlockedSupply + ((lockedSupply * lockingBoostMultiplerInBips) / BIPS);
    }

    function balanceOf(address user) public view returns (uint256) {
        Balances storage bal = _balances[user];
        return bal.unlocked + ((bal.locked * lockingBoostMultiplerInBips) / BIPS);
    }

    /// @dev Calculates when the next unlock event will occur given the current epoch.
    /// It ensures that the unlock timing coincides with the intervals at which rewards are distributed.
    /// If the current time is within an ongoing reward interval, the function establishes the
    /// unlock period to begin at the next epoch.
    /// For if you stake at week 1 + 4 days, you will be able to unlock at the end of week 15.
    // |    week -1   |    week 1    |    week 2    |      ...     |    week 13   |    week 14   |
    // |--------------|--------------|--------------|--------------|--------------|--------------|
    // |                   ^ block.timestamp                                      |
    // |                             ^ lock starts (adjusted)                                    ^ unlock ends (nextUnlockTime)
    function nextUnlockTime() public view returns (uint256) {
        return ((block.timestamp / rewardsDuration) * rewardsDuration) + rewardsDuration + lockDuration;
    }

    function lastTimeRewardApplicable(address rewardToken) public view returns (uint256) {
        return MathLib.min(block.timestamp, _rewardData[rewardToken].periodFinish);
    }

    function rewardPerToken(address rewardToken) public view returns (uint256) {
        return _rewardPerToken(rewardToken, lastTimeRewardApplicable(rewardToken), totalSupply());
    }

    function _rewardPerToken(address rewardToken, uint256 lastTimeRewardApplicable_, uint256 totalSupply_) public view returns (uint256) {
        if (totalSupply_ == 0) {
            return _rewardData[rewardToken].rewardPerTokenStored;
        }

        uint256 timeElapsed = lastTimeRewardApplicable_ - _rewardData[rewardToken].lastUpdateTime;
        uint256 pendingRewardsPerToken = (timeElapsed * _rewardData[rewardToken].rewardRate * 1e18) / totalSupply_;

        return _rewardData[rewardToken].rewardPerTokenStored + pendingRewardsPerToken;
    }

    function earned(address user, address rewardToken) public view returns (uint256) {
        return _earned(user, balanceOf(user), rewardToken, rewardPerToken(rewardToken));
    }

    function _earned(address user, uint256 balance_, address rewardToken, uint256 rewardPerToken_) internal view returns (uint256) {
        uint256 pendingUserRewardsPerToken = rewardPerToken_ - userRewardPerTokenPaid[user][rewardToken];
        return ((balance_ * pendingUserRewardsPerToken) / 1e18) + rewards[user][rewardToken];
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////////////
    function addReward(address rewardToken) public onlyOwner {
        if (rewardToken == address(0)) {
            revert ErrInvalidTokenAddress();
        }

        if (rewardTokens.length == MAX_NUM_REWARDS) {
            revert ErrMaxRewardsExceeded();
        }

        rewardTokens.push(rewardToken);
    }

    function setMinLockAmount(uint256 _minLockAmount) external onlyOwner {
        emit LogSetMinLockAmount(minLockAmount, _minLockAmount);
        minLockAmount = _minLockAmount;
    }

    function recover(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        if (tokenAddress == stakingToken) {
            revert ErrInvalidTokenAddress();
        }

        tokenAddress.safeTransfer(owner, tokenAmount);
        emit LogRecovered(tokenAddress, tokenAmount);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// EMERGENCY FUNCTIONS
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
    function notifyRewardAmount(address rewardToken, uint256 amount) external onlyOperators {
        _updateRewards();
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);

        Reward storage reward = _rewardData[rewardToken];

        // Take the remainder of the current rewards and add it to the amount for the next period
        if (block.timestamp < reward.periodFinish) {
            amount += (reward.periodFinish - block.timestamp) * reward.rewardRate;
        }

        reward.rewardRate = amount / rewardsDuration;
        reward.lastUpdateTime = block.timestamp;
        reward.periodFinish = block.timestamp + rewardsDuration;

        emit LogRewardAdded(amount);
    }

    /// @notice Updates the balances of the given user and lock indexes
    // Should be called once a `rewardDuration` (for example, every week)
    function processExpiredLocks(address[] memory users, uint256[] calldata lockIndexes) external onlyOperators {
        if (users.length != lockIndexes.length) {
            revert ErrLengthMismatch();
        }

        _updateRewardsForUsers(users);

        // Release all expired users' locks
        for (uint256 i; i < users.length; ) {
            address user = users[i];
            Balances storage bal = _balances[user];
            LockedBalance[] storage locks = _userLocks[user];

            if (locks.length == 0) {
                revert ErrNoLocks();
            }

            uint256 index = lockIndexes[i];

            // prohibit releasing non-expired locks
            if (locks[index].unlockTime > block.timestamp) {
                revert ErrLockNotExpired();
            }

            uint256 amount = locks[index].amount;
            uint256 lastIndex = locks.length - 1;

            /// Last lock index changed place with the one we just swapped.
            if (lastLockIndex[user] == lastIndex) {
                lastLockIndex[user] = index;
            }

            locks[index] = locks[lastIndex];
            locks.pop();

            unlockedSupply += amount;
            lockedSupply -= amount;

            bal.unlocked += amount;
            bal.locked -= amount;

            emit LogUnlocked(user, amount, index);
            emit LogLockIndexChanged(user, lastIndex, index);

            unchecked {
                ++i;
            }
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////////////
    function _createLock(address user, uint256 amount) internal {
        Balances storage bal = _balances[user];
        uint256 _nextUnlockTime = nextUnlockTime();
        uint256 _lastLockIndex = lastLockIndex[user];
        uint256 lockCount = _userLocks[user].length;

        bal.locked += amount;
        lockedSupply += amount;

        // Add to current lock if it's the same unlock time or the first one
        // userLocks is sorted by unlockTime, so the last lock is the most recent one
        if (lockCount == 0 || _userLocks[user][_lastLockIndex].unlockTime < _nextUnlockTime) {
            // Limit the number of locks per user to avoid too much gas costs per user
            // when looping through the locks
            if (lockCount == maxLocks) {
                revert ErrMaxUserLocksExceeded();
            }

            if (amount < minLockAmount) {
                revert ErrLockAmountTooSmall();
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

        emit LogLocked(user, amount, _nextUnlockTime, lockCount);
    }

    /// @dev Update the global accumulated rewards from the last update to this point,
    /// in relation with the `totalSupply`
    ///
    /// The idea is to allow everyone that are currently part of that supply to get their allocated
    /// reward share.
    ///
    /// Each user's reward share is taking in account when `rewards[user][token] = _earned(...)`
    /// is called. And only updated when a user is interacting with `stake`, `lock`, `withdraw`
    /// or `getRewards`.
    ///
    /// Otherwise, if it's yet-to-be-updated, it's going to get considered as part of the pending
    /// yet-to-receive rewards in the `earned` function.
    function _updateRewardsGlobal(address token_, uint256 totalSupply_) internal returns (uint256 rewardPerToken_) {
        uint256 lastTimeRewardApplicable_ = lastTimeRewardApplicable(token_);
        rewardPerToken_ = _rewardPerToken(token_, lastTimeRewardApplicable_, totalSupply_);

        _rewardData[token_].rewardPerTokenStored = rewardPerToken_;
        _rewardData[token_].lastUpdateTime = lastTimeRewardApplicable_;
    }

    function _udpateUserRewards(address user_, uint256 balance_, address token_, uint256 rewardPerToken_) internal {
        rewards[user_][token_] = _earned(user_, balance_, token_, rewardPerToken_);
        userRewardPerTokenPaid[user_][token_] = rewardPerToken_;
    }

    /// @dev Simplest version of updating rewards. Mainly used by `notifyRewardAmount`.
    /// where we don't need to update any particular user but the global state for
    /// each reward tokens only.
    function _updateRewards() internal {
        uint256 totalSupply_ = totalSupply();

        for (uint256 i; i < rewardTokens.length; ) {
            _updateRewardsGlobal(rewardTokens[i], totalSupply_);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev More gas efficient version of `_updateRewards` when we
    /// only need to update the rewards for a single user.
    function _updateRewardsForUser(address user) internal {
        uint256 balance = balanceOf(user);
        uint256 totalSupply_ = totalSupply();

        for (uint256 i; i < rewardTokens.length; ) {
            address token = rewardTokens[i];
            _udpateUserRewards(user, balance, token, _updateRewardsGlobal(token, totalSupply_));

            unchecked {
                ++i;
            }
        }
    }

    /// @dev `_updateRewardsForUser` for multiple users.
    function _updateRewardsForUsers(address[] memory users) internal {
        uint256 totalSupply_ = totalSupply();

        for (uint256 i; i < rewardTokens.length; ) {
            address token = rewardTokens[i];
            uint256 rewardPerToken_ = _updateRewardsGlobal(token, totalSupply_);

            // Record each user's rewards
            for (uint256 j; j < users.length; ) {
                address user = users[j];
                _udpateUserRewards(user, balanceOf(user), token, rewardPerToken_);

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    function _getRewards() internal {
        for (uint256 i; i < rewardTokens.length; ) {
            address rewardToken = rewardTokens[i];
            uint256 reward = rewards[msg.sender][rewardToken];

            if (reward > 0) {
                rewards[msg.sender][rewardToken] = 0;
                rewardToken.safeTransfer(msg.sender, reward);

                emit LogRewardPaid(msg.sender, rewardToken, reward);
            }

            unchecked {
                ++i;
            }
        }
    }
}
