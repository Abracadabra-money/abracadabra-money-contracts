// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {OperatableV2} from "mixins/OperatableV2.sol";
import {Pausable} from "openzeppelin-contracts/security/Pausable.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {MathLib} from "libraries/MathLib.sol";
import {BoringMath} from "libraries/compat/BoringMath.sol";

/// @notice A staking contract that distributes multiple rewards to stakers.
/// @author Modified from Curve Finance's MultiRewards contract
/// https://github.com/curvefi/multi-rewards/blob/master/contracts/MultiRewards.sol
contract MultiRewardsStaking is OperatableV2, ReentrancyGuard, Pausable {
    using BoringMath for uint256;
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
    error ErrCannotRecoverRewardToken();

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

    function stake(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) {
            revert ErrZeroAmount();
        }

        _updateReward(msg.sender);
        totalSupply += amount;
        balanceOf[msg.sender] += amount;

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit LogStaked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant {
        if (amount == 0) {
            revert ErrZeroAmount();
        }

        _updateReward(msg.sender);
        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;

        stakingToken.safeTransfer(msg.sender, amount);
        emit LogWithdrawn(msg.sender, amount);
    }

    function getRewards() public nonReentrant {
        _updateReward(msg.sender);

        for (uint256 i; i < rewardTokens.length; ) {
            address _rewardsToken = rewardTokens[i];
            uint256 reward = rewards[msg.sender][_rewardsToken];

            if (reward > 0) {
                rewards[msg.sender][_rewardsToken] = 0;
                _rewardsToken.safeTransfer(msg.sender, reward);

                emit LogRewardPaid(msg.sender, _rewardsToken, reward);
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
    function lastTimeRewardApplicable(address _rewardsToken) public view returns (uint256) {
        return MathLib.min(block.timestamp, rewardData[_rewardsToken].periodFinish);
    }

    function rewardPerToken(address _rewardsToken) public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardData[_rewardsToken].rewardPerTokenStored;
        }

        return
            rewardData[_rewardsToken].rewardPerTokenStored.add(
                lastTimeRewardApplicable(_rewardsToken)
                    .sub(rewardData[_rewardsToken].lastUpdateTime)
                    .mul(rewardData[_rewardsToken].rewardRate)
                    .mul(1e18)
                    .div(totalSupply)
            );
    }

    function earned(address account, address _rewardsToken) public view returns (uint256) {
        return
            balanceOf[account].mul(rewardPerToken(_rewardsToken).sub(userRewardPerTokenPaid[account][_rewardsToken])).div(1e18).add(
                rewards[account][_rewardsToken]
            );
    }

    function getRewardForDuration(address _rewardsToken) external view returns (uint256) {
        return rewardData[_rewardsToken].rewardRate * rewardData[_rewardsToken].rewardsDuration;
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////////////
    function addReward(address _rewardsToken, uint256 _rewardsDuration) public onlyOwner {
        if (rewardData[_rewardsToken].rewardsDuration != 0) {
            revert ErrRewardAlreadyAdded();
        }
        if(_rewardsDuration == 0) {
            revert ErrZeroDuration();
        }

        rewardTokens.push(_rewardsToken);
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
    }

    function setRewardsDuration(address _rewardsToken, uint256 _rewardsDuration) external onlyOwner {
        if (block.timestamp <= rewardData[_rewardsToken].periodFinish) {
            revert ErrRewardPeriodStillActive();
        }
        if (_rewardsDuration == 0) {
            revert ErrZeroDuration();
        }

        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
        emit LogRewardsDurationUpdated(_rewardsToken, rewardData[_rewardsToken].rewardsDuration);
    }

    function recover(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        if (tokenAddress == stakingToken) {
            revert ErrInvalidTokenAddress();
        }

        if (rewardData[tokenAddress].lastUpdateTime != 0) {
            revert ErrCannotRecoverRewardToken();
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
    function notifyRewardAmount(address _rewardsToken, uint256 reward) external onlyOperators {
        _updateReward(address(0));
        _rewardsToken.safeTransferFrom(msg.sender, address(this), reward);

        if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
            rewardData[_rewardsToken].rewardRate = reward / rewardData[_rewardsToken].rewardsDuration;
        } else {
            uint256 remaining = rewardData[_rewardsToken].periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardData[_rewardsToken].rewardRate);
            rewardData[_rewardsToken].rewardRate = reward.add(leftover).div(rewardData[_rewardsToken].rewardsDuration);
        }

        rewardData[_rewardsToken].lastUpdateTime = block.timestamp;
        rewardData[_rewardsToken].periodFinish = block.timestamp.add(rewardData[_rewardsToken].rewardsDuration);

        emit LogRewardAdded(reward);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////////////
    function _updateReward(address account) internal {
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
