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
contract MultiRewardsStakingWithBoosting is OperatableV2, Pausable {
    using SafeTransferLib for address;

    event LogRewardAdded(uint256 reward);
    event LogStaked(address indexed user, uint256 amount);
    event LogWithdrawn(address indexed user, uint256 amount);
    event LogRewardPaid(address indexed user, address indexed rewardsToken, uint256 reward);
    event LogRewardsDurationUpdated(address token, uint256 newDuration);
    event LogRecovered(address token, uint256 amount);

    error ErrZeroAmount();
    error ErrZeroDuration();
    error ErrRewardAlreadyAdded();
    error ErrRewardPeriodStillActive();
    error ErrInvalidTokenAddress();
    error ErrMaxUserLocksExceeded();
    error ErrExceedUnlocked();

    struct Reward {
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    struct Balances {
        uint256 total;
        // Caching, need to be updated offchain
        uint256 unlocked;
        uint256 locked;
    }

    struct LockedBalance {
        uint256 amount;
        uint256 unlockTime;
    }

    uint256 public constant MAX_USER_LOCKS = 10;

    uint256 public immutable lockingBoostMultipler;
    uint256 public immutable rewardsDuration;
    uint256 public immutable lockDuration;

    address public immutable stakingToken;

    mapping(address token => Reward info) private _rewardData;
    mapping(address => LockedBalance[]) private _userLocks;

    mapping(address => Balances) private balances;
    mapping(address => LockedBalance[]) private userLocks;

    mapping(address user => mapping(address token => uint256 amount)) public userRewardPerTokenPaid;
    mapping(address user => mapping(address token => uint256 amount)) public rewards;

    address[] public rewardTokens;

    uint256 public totalSupply;
    uint256 public lockedSupply; // cached

    // unlocked = totalSupply - lockedSupply

    ///
    /// @dev Constructor
    /// @param _stakingToken The token that is being staked
    /// @param _owner The owner of the contract
    /// @param _lockingBoostMultipler The multiplier for the locking boost. 3 means if you stake 100, you get 300 locked
    /// @param _rewardsDuration The duration of the rewards period in seconds, should be 7 days by default.
    /// @param _lockDuration The duration of the lock period in seconds, should be 13 weeks by default.
    constructor(
        address _stakingToken,
        address _owner,
        uint256 _lockingBoostMultipler,
        uint256 _rewardsDuratio,
        uint256 _lockDuration
    ) OperatableV2(_owner) {
        stakingToken = _stakingToken;
        lockingBoostMultipler = _lockingBoostMultipler;
        rewardsDuration = _rewardsDuration;
        lockDuration = _lockDuration;
    }

    /// @notice Stakes the given amount of tokens for the given user.
    /// @param amount The amount of tokens to stake
    /// @param lock If true, the tokens will be locked for the lock duration for a reward boost
    function stake(uint256 amount, bool lock) public virtual whenNotPaused {
        if (amount == 0) {
            revert ErrZeroAmount();
        }

        _updateRewards(msg.sender);

        Balances storage bal = balances[msg.sender];
        bal.total += amount;
        totalSupply += amount;

        if (lock) {
            bal.locked += amount;
            lockedSupply += amount;

            // Get the current unlock giving the beginning of this reward period
            // |    week -1   |    week 1    |    week 2    |      ...     |    week 13   |
            // |--------------|--------------|--------------|--------------|--------------|
            // |                   ^ let's say we are here                                |
            // |              ^ lock starts (adjusted)                                    ^ unlock ends (nextUnlockTime)
            uint256 nextUnlockTime = nextUnlockTime();
            uint256 idx = userLocks[msg.sender].length;

            // Limit the number of locks per user to avoid too much gas costs per user
            // when looping through the locks
            if (idx == MAX_USER_LOCKS) {
                revert ErrMaxUserLocksExceeded();
            }

            // First lock or current lock started before this reward period
            if (idx == 0 || userLocks[msg.sender][idx - 1].unlockTime < nextUnlockTime) {
                userLocks[msg.sender].push(LockedBalance({amount: amount, unlockTime: unlockTime}));
            }
            /// It's the same reward period, so we just add the amount to the current lock
            else {
                userLocks[msg.sender][idx - 1].amount += amount;
            }
        } else {
            bal.unlocked += amount;
        }

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit LogStaked(msg.sender, amount);
    }

    /// @notice Withdraws the given amount of tokens for the given user.
    /// Will use the unlocked balance first, then iterate through the locks to find
    /// expired locks, prunning them and cumulate the amounts to withdraw.
    /// @param amount The amount of tokens to withdraw
    function withdraw(uint256 amount) public virtual {
        if (amount == 0) {
            revert ErrZeroAmount();
        }

        uint256 withdrawable = pruneExpiredLocks(msg.sender) + balances[msg.sender].unlocked;
        if (amount > withdrawable) {
            revert ErrExceedUnlocked();
        }

        _updateRewards(msg.sender);
        totalSupply -= amount;

        Balances storage bal = balances[msg.sender];
        bal.total -= amount;
        bal.unlocked -= amount;

        stakingToken.safeTransfer(msg.sender, amount);
        emit LogWithdrawn(msg.sender, amount);
    }

    function extendLock(uint256 lockIndex) public {
        if (lockIndex >= userLocks[msg.sender].length) {
            revert ErrInvalidLockIndex();
        }
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

    function exit() public virtual {
        withdraw(balanceOf[msg.sender]);
        getRewards();
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// PERMISSIONLESS
    //////////////////////////////////////////////////////////////////////////////////////////////

    /// Check the released amount for all locks and prune.
    /// Update unlocked/lock user balance + boostedSupply
    /// @param user The user to update the locks for
    /// @return the amount of tokens from pruned locks
    function pruneExpiredLocks(address user) external returns (uint256 unlockedAmount) {
        LockedBalance[] storage locks = userLocks[user];
        uint256 length = locks.length;

        if (length == 0) {
            return 0;
        }

        Balances storage bal = balances[user];

        uint256 unlockedAmount;

        for (uint256 i = length - 1; i < 0; i--) {
            // lock expired
            if (locks[i].unlockTime <= block.timestamp) {
                unlockedAmount += locks[i].amount;
                locks.pop();
            }
        }

        bal.locked -= unlockedAmount;
        bal.unlocked += unlockedAmount;
        lockedSupply -= unlockedAmount;
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////////////
    function rewardData(address token) external view returns (Reward memory) {
        return _rewardData[token];
    }

    /// Calculates when the next unlock event will occur given the current epoch.
    /// It ensures that the unlock timing coincides with the intervals at which rewards are distributed.
    /// If the current time is within an ongoing reward interval, the function establishes the
    /// unlock period to begin from the start of this current interval, extended by the duration
    /// of the lock period.
    function nextUnlockTime() external view returns (uint256) {
        return block.timestamp.div(rewardsDuration).mul(rewardsDuration).add(lockDuration);
    }

    function lastTimeRewardApplicable(address rewardToken) public view returns (uint256) {
        return MathLib.min(block.timestamp, _rewardData[rewardToken].periodFinish);
    }

    function rewardPerToken(address rewardToken) public view returns (uint256) {
        if (totalSupply == 0) {
            return _rewardData[rewardToken].rewardPerTokenStored;
        }

        uint256 timeElapsed = lastTimeRewardApplicable(rewardToken) - _rewardData[rewardToken].lastUpdateTime;
        uint256 pendingRewardsPerToken = (timeElapsed * _rewardData[rewardToken].rewardRate * 1e18) / totalSupply;

        return _rewardData[rewardToken].rewardPerTokenStored + pendingRewardsPerToken;
    }

    function earned(address user, address rewardToken) public view returns (uint256) {
        uint256 pendingUserRewardsPerToken = rewardPerToken(rewardToken) - userRewardPerTokenPaid[user][rewardToken];

        return ((balanceOf[user] * pendingUserRewardsPerToken) / 1e18) + rewards[user][rewardToken];
    }

    function getRewardForDuration(address rewardToken) external view returns (uint256) {
        return _rewardData[rewardToken].rewardRate * _rewardData[rewardToken].rewardsDuration;
    }

    function getRewardTokenLength() external view returns (uint256) {
        return rewardTokens.length;
    }

    function isSupportedReward(address rewardToken) external view returns (bool) {
        return _rewardData[rewardToken].rewardsDuration != 0;
    }

    function totalBalance(address user) external view returns (uint256 amount) {
        return balances[user].total;
    }

    // TODO: optimize, is this really necessary to build the array?
    // The FE could just call the lockedBalances function and get the data from there
    function lockedBalances(
        address user
    ) external view returns (uint256 total, uint256 unlockable, uint256 locked, LockedBalance[] memory lockData) {
        LockedBalance[] storage locks = userLocks[user];
        uint256 idx;

        for (uint256 i = 0; i < locks.length; i++) {
            if (locks[i].unlockTime > block.timestamp) {
                if (idx == 0) {
                    lockData = new LockedBalance[](locks.length - i);
                }

                lockData[idx] = locks[i];
                idx++;

                locked += locks[i].amount;
            } else {
                unlockable += locks[i].amount;
            }
        }

        // TODO: verify if we need to return the total and also if it should be the tota
        return (balances[user].locked, unlockable, locked, lockData);
    }

    function withdrawableBalance(address user) public view returns (uint256 amount) {
        Balances storage bal = balances[user];
        amount = bal.unlocked;

        for (uint256 i = 0; i < locks.length; i++) {
            if (locks[i].unlockTime <= block.timestamp) {
                amount += locks[i].amount;
            }
        }

        return amount;
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////////////
    function addReward(address rewardToken, uint256 _rewardsDuration) public onlyOwner {
        if (rewardToken == address(0)) {
            revert ErrInvalidTokenAddress();
        }
        if (_rewardData[rewardToken].rewardsDuration != 0) {
            revert ErrRewardAlreadyAdded();
        }
        if (_rewardsDuration == 0) {
            revert ErrZeroDuration();
        }

        rewardTokens.push(rewardToken);
        _rewardData[rewardToken].rewardsDuration = _rewardsDuration;
    }

    function setRewardsDuration(address rewardToken, uint256 _rewardsDuration) external onlyOwner {
        if (block.timestamp <= _rewardData[rewardToken].periodFinish) {
            revert ErrRewardPeriodStillActive();
        }
        if (_rewardsDuration == 0) {
            revert ErrZeroDuration();
        }

        _rewardData[rewardToken].rewardsDuration = _rewardsDuration;
        emit LogRewardsDurationUpdated(rewardToken, _rewardData[rewardToken].rewardsDuration);
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
        if (_rewardData[rewardToken].rewardsDuration == 0) {
            revert ErrInvalidTokenAddress();
        }

        _updateRewards(address(0));
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);

        // Take the remainder of the current rewards and add it to the amount for the next period
        if (block.timestamp < _rewardData[rewardToken].periodFinish) {
            amount += (_rewardData[rewardToken].periodFinish - block.timestamp) * _rewardData[rewardToken].rewardRate;
        }

        _rewardData[rewardToken].rewardRate = amount / _rewardData[rewardToken].rewardsDuration;
        _rewardData[rewardToken].lastUpdateTime = block.timestamp;
        _rewardData[rewardToken].periodFinish = block.timestamp + _rewardData[rewardToken].rewardsDuration;

        emit LogRewardAdded(amount);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////////////
    function _updateRewards(address user) internal {
        for (uint256 i; i < rewardTokens.length; ) {
            address token = rewardTokens[i];

            _rewardData[token].rewardPerTokenStored = rewardPerToken(token);
            _rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);

            if (user != address(0)) {
                rewards[user][token] = earned(user, token);
                userRewardPerTokenPaid[user][token] = _rewardData[token].rewardPerTokenStored;
            }

            unchecked {
                ++i;
            }
        }
    }
}
