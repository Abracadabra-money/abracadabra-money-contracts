// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {OperatableV2} from "mixins/OperatableV2.sol";
import {Pausable} from "openzeppelin-contracts/security/Pausable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {MathLib} from "libraries/MathLib.sol";

/// @notice A staking contract that distributes multiple rewards to stakers.
/// @author Modified from Curve Finance's MultiRewards contract
/// https://github.com/curvefi/multi-rewards/blob/master/contracts/MultiRewards.sol
contract MultiRewardsStaking is OperatableV2, Pausable {
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

    mapping(address token => Reward info) public rewardData;
    mapping(address user => uint256 amount) public balanceOf;
    mapping(address user => mapping(address token => uint256 amount)) public userRewardPerTokenPaid;
    mapping(address user => mapping(address token => uint256 amount)) public rewards;

    address[] public rewardTokens;
    uint256 public totalSupply;

    constructor(address _stakingToken, address _owner) OperatableV2(_owner) {
        stakingToken = _stakingToken;
    }

    function stake(uint256 amount) external whenNotPaused {
        if (amount == 0) {
            revert ErrZeroAmount();
        }

        _updateRewards(msg.sender);
        totalSupply += amount;
        balanceOf[msg.sender] += amount;

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit LogStaked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public {
        if (amount == 0) {
            revert ErrZeroAmount();
        }

        _updateRewards(msg.sender);
        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;

        stakingToken.safeTransfer(msg.sender, amount);
        emit LogWithdrawn(msg.sender, amount);
    }

    function getRewards() public {
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

    function exit() external {
        withdraw(balanceOf[msg.sender]);
        getRewards();
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////////////
    function lastTimeRewardApplicable(address rewardToken) public view returns (uint256) {
        return MathLib.min(block.timestamp, rewardData[rewardToken].periodFinish);
    }
    
    function rewardPerToken(address rewardToken) public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardData[rewardToken].rewardPerTokenStored;
        }

        return
            rewardData[rewardToken].rewardPerTokenStored +
            (((lastTimeRewardApplicable(rewardToken) - rewardData[rewardToken].lastUpdateTime) *
                rewardData[rewardToken].rewardRate *
                1e18) / totalSupply);
    }

    function earned(address account, address rewardToken) public view returns (uint256) {
        return
            (((balanceOf[account] * rewardPerToken(rewardToken)) - userRewardPerTokenPaid[account][rewardToken]) / 1e18) +
            rewards[account][rewardToken];
    }

    function getRewardForDuration(address rewardToken) external view returns (uint256) {
        return rewardData[rewardToken].rewardRate * rewardData[rewardToken].rewardsDuration;
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////////////
    function addReward(address rewardToken, uint256 _rewardsDuration) public onlyOwner {
        if (rewardData[rewardToken].rewardsDuration != 0) {
            revert ErrRewardAlreadyAdded();
        }
        if (_rewardsDuration == 0) {
            revert ErrZeroDuration();
        }

        rewardTokens.push(rewardToken);
        rewardData[rewardToken].rewardsDuration = _rewardsDuration;
    }

    function setRewardsDuration(address rewardToken, uint256 _rewardsDuration) external onlyOwner {
        if (block.timestamp <= rewardData[rewardToken].periodFinish) {
            revert ErrRewardPeriodStillActive();
        }
        if (_rewardsDuration == 0) {
            revert ErrZeroDuration();
        }

        rewardData[rewardToken].rewardsDuration = _rewardsDuration;
        emit LogRewardsDurationUpdated(rewardToken, rewardData[rewardToken].rewardsDuration);
    }

    /// @notice Allows to recover any ERC20 token sent to the contract by mistake
    /// This cannot be used to recover staking or rewards tokens.
    function recover(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        if (tokenAddress == stakingToken || rewardData[tokenAddress].lastUpdateTime != 0) {
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
        if (block.timestamp < rewardData[rewardToken].periodFinish) {
            amount += (rewardData[rewardToken].periodFinish - block.timestamp) * rewardData[rewardToken].rewardRate;
        }

        rewardData[rewardToken].rewardRate = amount / rewardData[rewardToken].rewardsDuration;
        rewardData[rewardToken].lastUpdateTime = block.timestamp;
        rewardData[rewardToken].periodFinish = block.timestamp + rewardData[rewardToken].rewardsDuration;

        emit LogRewardAdded(amount);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////////////
    function _updateRewards(address account) internal {
        for (uint256 i; i < rewardTokens.length; ) {
            address token = rewardTokens[i];

            rewardData[token].rewardPerTokenStored = rewardPerToken(token);
            rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);

            if (account != address(0)) {
                rewards[account][token] = earned(account, token);
                userRewardPerTokenPaid[account][token] = rewardData[token].rewardPerTokenStored;
            }

            unchecked {
                ++i;
            }
        }
    }
}
