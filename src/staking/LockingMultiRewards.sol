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
    event LogStaked(address indexed user, uint256 amount, bool locked);
    event LogWithdrawn(address indexed user, uint256 amount);
    event LogRewardPaid(address indexed user, address indexed rewardsToken, uint256 reward);
    event LogRewardsDurationUpdated(address token, uint256 newDuration);
    event LogRecovered(address token, uint256 amount);
    event LogUnlocked(address indexed user, uint256 amount);

    error ErrZeroAmount();
    error ErrZeroDuration();
    error ErrRewardPeriodStillActive();
    error ErrInvalidTokenAddress();
    error ErrMaxUserLocksExceeded();
    error ErrExceedUnlocked();
    error ErrPendingLocks();

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

    uint256 public immutable maxLocks;
    uint256 public immutable lockingBoostMultiplerInBips;
    uint256 public immutable rewardsDuration;
    uint256 public immutable lockDuration;
    address public immutable stakingToken;

    mapping(address token => Reward info) private _rewardData;
    mapping(address user => Balances balances) private _balances;
    mapping(address user => LockedBalance[] locks) private _userLocks; // sorted by unlockTime

    mapping(address user => mapping(address token => uint256 amount)) public userRewardPerTokenPaid;
    mapping(address user => mapping(address token => uint256 amount)) public rewards;

    address[] public rewardTokens;

    uint256 public lockedSupply; // all locked boosted deposits
    uint256 public unlockedSupply; // all unlocked unboosted deposits

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

        _updateRewards(msg.sender);

        Balances storage bal = _balances[msg.sender];

        if (lock_) {
            _lock(amount, bal);
        } else {
            bal.unlocked += amount;
            unlockedSupply += amount;
        }

        emit LogStaked(msg.sender, amount, lock_);
    }

    /// @notice Locks an existing unlocked balance.
    function lock(uint256 amount) public whenNotPaused {
        if (amount == 0) {
            revert ErrZeroAmount();
        }

        Balances storage bal = _balances[msg.sender];
        if (amount > bal.unlocked) {
            revert ErrExceedUnlocked();
        }

        _updateRewards(msg.sender);
        _lock(amount, bal);
    }

    function _lock(uint256 amount, Balances storage bal) internal {
        uint256 _nextUnlockTime = nextUnlockTime();
        uint256 lockCount = _userLocks[msg.sender].length;

        bal.locked += amount;
        lockedSupply += amount;

        // Add to current lock if it's the same unlock time or the first one
        // userLocks is sorted by unlockTime, so the last lock is the most recent one
        if (lockCount == 0 || _userLocks[msg.sender][lockCount - 1].unlockTime < _nextUnlockTime) {
            // Limit the number of locks per user to avoid too much gas costs per user
            // when looping through the locks
            if (lockCount == maxLocks) {
                revert ErrMaxUserLocksExceeded();
            }

            _userLocks[msg.sender].push(LockedBalance({amount: amount, unlockTime: _nextUnlockTime}));
        }
        /// It's the same reward period, so we just add the amount to the current lock
        else {
            _userLocks[msg.sender][lockCount - 1].amount += amount;
        }
    }

    /// @notice Withdraws the given amount of tokens for the given user.
    /// Will use the unlocked balance first, then iterate through the locks to find
    /// expired locks, prunning them and cumulate the amounts to withdraw.
    /// @param amount The amount of tokens to withdraw
    function withdraw(uint256 amount) public virtual {
        if (amount == 0) {
            revert ErrZeroAmount();
        }

        Balances storage bal = _balances[msg.sender];
        if (amount > bal.unlocked) {
            revert ErrExceedUnlocked();
        }

        _updateRewards(msg.sender);

        unlockedSupply -= amount;
        bal.unlocked -= amount;

        stakingToken.safeTransfer(msg.sender, amount);
        emit LogWithdrawn(msg.sender, amount);
    }

    function withdrawWithRewards(uint256 amount) public virtual {
        withdraw(amount);
        getRewards();
    }

    function getRewards() public virtual {
        _updateRewards(msg.sender);

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

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////////////
    function rewardData(address token) external view returns (Reward memory) {
        return _rewardData[token];
    }

    function balances(address user) external view returns (Balances memory) {
        return _balances[user];
    }

    function userLocks(address user) external view returns (LockedBalance[] memory) {
        return _userLocks[user];
    }

    function unlocked(address user) external view returns (uint256) {
        return _balances[user].unlocked;
    }

    function totalSupply() public view returns (uint256) {
        return unlockedSupply + ((lockedSupply * lockingBoostMultiplerInBips) / BIPS);
    }

    function balanceOf(address user) public view returns (uint256) {
        return _balances[user].unlocked + ((_balances[user].locked * lockingBoostMultiplerInBips) / BIPS);
    }

    /// Calculates when the next unlock event will occur given the current epoch.
    /// It ensures that the unlock timing coincides with the intervals at which rewards are distributed.
    /// If the current time is within an ongoing reward interval, the function establishes the
    /// unlock period to begin at the next epoch.
    /// For if you stake at week 1 + 4 days, you will be able to unlock at the end of week 15.
    // |    week -1   |    week 1    |    week 2    |      ...     |    week 13   |    week 14   |
    // |--------------|--------------|--------------|--------------|--------------|--------------|
    // |                   ^ block.timestamp                                      |
    // |                             ^ lock starts (adjusted)                                    ^ unlock endd (nextUnlockTime)
    function nextUnlockTime() public view returns (uint256) {
        return ((block.timestamp / rewardsDuration) * rewardsDuration) + rewardsDuration + lockDuration;
    }

    function lastTimeRewardApplicable(address rewardToken) public view returns (uint256) {
        return MathLib.min(block.timestamp, _rewardData[rewardToken].periodFinish);
    }

    function rewardPerToken(address rewardToken) public view returns (uint256) {
        return _rewardPerToken(rewardToken, totalSupply());
    }

    function _rewardPerToken(address rewardToken, uint256 _totalSupply) public view returns (uint256) {
        if (_totalSupply == 0) {
            return _rewardData[rewardToken].rewardPerTokenStored;
        }

        uint256 timeElapsed = lastTimeRewardApplicable(rewardToken) - _rewardData[rewardToken].lastUpdateTime;
        uint256 pendingRewardsPerToken = (timeElapsed * _rewardData[rewardToken].rewardRate * 1e18) / _totalSupply;

        return _rewardData[rewardToken].rewardPerTokenStored + pendingRewardsPerToken;
    }

    function earned(address user, address rewardToken) public view returns (uint256) {
        return _earned(user, balanceOf(user), rewardToken, rewardPerToken(rewardToken));
    }

    function _earned(address user, uint256 balance_, address rewardToken, uint256 rewardPerToken_) internal view returns (uint256) {
        uint256 pendingUserRewardsPerToken = rewardPerToken_ - userRewardPerTokenPaid[user][rewardToken];
        return ((balance_ * pendingUserRewardsPerToken) / 1e18) + rewards[user][rewardToken];
    }

    function getRewardForDuration(address rewardToken) external view returns (uint256) {
        return _rewardData[rewardToken].rewardRate * rewardsDuration;
    }

    function getRewardTokenLength() external view returns (uint256) {
        return rewardTokens.length;
    }

    function isSupportedReward(address rewardToken) external view returns (bool) {
        return _rewardData[rewardToken].rewardRate != 0;
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////////////
    function addReward(address rewardToken) public onlyOwner {
        if (rewardToken == address(0)) {
            revert ErrInvalidTokenAddress();
        }

        rewardTokens.push(rewardToken);
    }

    function recover(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        if (tokenAddress == stakingToken) {
            revert ErrInvalidTokenAddress();
        }

        tokenAddress.safeTransfer(owner, tokenAmount);
        emit LogRecovered(tokenAddress, tokenAmount);
    }

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
        _updateRewards(address(0));
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);

        // Take the remainder of the current rewards and add it to the amount for the next period
        if (block.timestamp < _rewardData[rewardToken].periodFinish) {
            amount += (_rewardData[rewardToken].periodFinish - block.timestamp) * _rewardData[rewardToken].rewardRate;
        }

        _rewardData[rewardToken].rewardRate = amount / rewardsDuration;
        _rewardData[rewardToken].lastUpdateTime = block.timestamp;
        _rewardData[rewardToken].periodFinish = block.timestamp + rewardsDuration;

        emit LogRewardAdded(amount);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// PERMISSIONLESS
    //////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Updates the balances of the given user, and returns the locked and unlocked balances.
    /// @dev Beware that this function is not gas efficient, and should be used only when necessary.
    // Should be called once a `rewardDuration` (for example, every week)
    function processExpiredLocks(address[] memory users) external {
        for (uint256 i; i < rewardTokens.length; ) {
            address token = rewardTokens[i];
            uint256 rewardPerToken_ = rewardPerToken(token);

            _rewardData[token].rewardPerTokenStored = rewardPerToken_;
            _rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);

            for (uint256 j; j < users.length; ) {
                address user = users[j];
                LockedBalance[] storage locks = _userLocks[user];
                Balances storage bal = _balances[users[j]];
                uint256 totalBalance = balanceOf(users[j]);
                uint256 unlockedAmount;

                rewards[user][token] = _earned(user, totalBalance, token, rewardPerToken_);
                userRewardPerTokenPaid[user][token] = rewardPerToken_;

                // Reverse loop, limited to `maxLocks`
                for (uint k = locks.length - 1; ; ) {
                    uint256 amount = locks[k].amount;

                    // lock is expired
                    if (locks[k].unlockTime <= block.timestamp) {
                        unlockedAmount += amount;
                        locks[k] = locks[locks.length - 1];
                        locks.pop();
                    }

                    if (k == 0) {
                        break;
                    }

                    unchecked {
                        --k;
                    }
                }

                unlockedSupply += unlockedAmount;
                lockedSupply -= unlockedAmount;

                bal.unlocked += unlockedAmount;
                bal.locked -= unlockedAmount;

                emit LogUnlocked(user, unlockedAmount);

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////////////
    function _updateRewards(address user) internal {
        for (uint256 i; i < rewardTokens.length; ) {
            address token = rewardTokens[i];
            uint256 rewardPerToken_ = rewardPerToken(token);

            _rewardData[token].rewardPerTokenStored = rewardPerToken_;
            _rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);

            if (user != address(0)) {
                rewards[user][token] = _earned(user, balanceOf(user), token, rewardPerToken_);
                userRewardPerTokenPaid[user][token] = _rewardData[token].rewardPerTokenStored;
            }

            unchecked {
                ++i;
            }
        }
    }
}
