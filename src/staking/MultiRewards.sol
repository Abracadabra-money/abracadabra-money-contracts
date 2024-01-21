// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {OperatableV2} from "mixins/OperatableV2.sol";
import {Pausable} from "openzeppelin-contracts/security/Pausable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {MathLib} from "libraries/MathLib.sol";

/// @notice A staking contract that distributes multiple rewards to stakers.
/// @author Modified from Curve Finance's MultiRewards contract
/// https://github.com/curvefi/multi-rewards/blob/master/contracts/MultiRewards.sol
contract MultiRewards is OperatableV2, Pausable {
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

    struct Reward {
        uint256 rewardsDuration;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    address public immutable stakingToken;

    mapping(address token => Reward info) private _rewardData;
    mapping(address user => uint256 amount) public balanceOf;
    mapping(address user => mapping(address token => uint256 amount)) public userRewardPerTokenPaid;
    mapping(address user => mapping(address token => uint256 amount)) public rewards;

    address[] public rewardTokens;
    uint256 public totalSupply;

    constructor(address _stakingToken, address _owner) OperatableV2(_owner) {
        stakingToken = _stakingToken;
    }

    function stake(uint256 amount) public virtual whenNotPaused {
        if (amount == 0) {
            revert ErrZeroAmount();
        }

        _updateRewards(msg.sender);
        totalSupply += amount;
        balanceOf[msg.sender] += amount;

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit LogStaked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public virtual {
        if (amount == 0) {
            revert ErrZeroAmount();
        }

        _updateRewards(msg.sender);
        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;

        stakingToken.safeTransfer(msg.sender, amount);
        emit LogWithdrawn(msg.sender, amount);
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
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////////////
    function rewardData(address token) external view returns (Reward memory) {
        return _rewardData[token];
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
