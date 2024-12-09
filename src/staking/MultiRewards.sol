// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {MathLib} from "/libraries/MathLib.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IRewardHandler {
    function notifyRewards(address _user, address _to, TokenAmount[] memory _rewards, bytes memory _data) external payable;
}

struct TokenAmount {
    address token;
    uint256 amount;
}

struct RewardHandlerParams {
    bytes data;
    uint256 value;
}

/// @notice A staking contract that distributes multiple rewards to stakers.
/// @author Modified from Curve Finance's MultiRewards contract
/// https://github.com/curvefi/multi-rewards/blob/master/contracts/MultiRewards.sol
contract MultiRewards is OwnableRoles, Pausable {
    using SafeTransferLib for address;

    event LogRewardAdded(uint256 reward);
    event LogStaked(address indexed user, uint256 amount);
    event LogWithdrawn(address indexed user, uint256 amount);
    event LogRewardPaid(address indexed user, address indexed rewardsToken, uint256 reward);
    event LogRewardsDurationUpdated(address token, uint256 newDuration);
    event LogRecovered(address token, uint256 amount);
    event LogRewardHandlerSet(address rewardHandler);

    error ErrZeroAmount();
    error ErrZeroDuration();
    error ErrRewardAlreadyAdded();
    error ErrRewardPeriodStillActive();
    error ErrInvalidTokenAddress();
    error ErrInvalidDecimals();

    struct Reward {
        uint256 rewardsDuration;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    // ROLES
    uint256 public constant ROLE_OPERATOR = _ROLE_0;
    uint256 public constant ROLE_REWARD_DISTRIBUTOR = _ROLE_1;

    address public immutable stakingToken;

    mapping(address token => Reward info) private _rewardData;
    mapping(address user => uint256 amount) public balanceOf;
    mapping(address user => mapping(address token => uint256 amount)) public userRewardPerTokenPaid;
    mapping(address user => mapping(address token => uint256 amount)) public rewards;

    address[] public rewardTokens;
    uint256 public totalSupply;
    IRewardHandler public rewardHandler;

    constructor(address _stakingToken, address _owner) {
        if (IERC20Metadata(_stakingToken).decimals() != 18) {
            revert ErrInvalidDecimals();
        }

        _initializeOwner(_owner);
        stakingToken = _stakingToken;
    }

    function stake(uint256 amount) public virtual whenNotPaused {
        _stakeFor(msg.sender, amount);
    }

    function withdraw(uint256 amount) public virtual {
        _withdrawFor(msg.sender, amount);
    }

    function getRewards() public virtual {
        _getRewardsFor(msg.sender);
    }

    function getRewards(address to, RewardHandlerParams memory params) public payable virtual {
        _getRewardsFor(msg.sender, to, params);
    }

    function exit() public virtual {
        _exitFor(msg.sender);
    }

    function exit(address to, RewardHandlerParams memory params) public payable virtual {
        _exitFor(msg.sender, to, params);
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

        tokenAddress.safeTransfer(owner(), tokenAmount);
        emit LogRecovered(tokenAddress, tokenAmount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setRewardHandler(address _rewardHandler) external onlyOwner {
        rewardHandler = IRewardHandler(_rewardHandler);
        emit LogRewardHandlerSet(_rewardHandler);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS
    //////////////////////////////////////////////////////////////////////////////////////////////

    function stakeFor(address user, uint256 amount) public virtual onlyOwnerOrRoles(ROLE_OPERATOR) {
        _stakeFor(user, amount);
    }

    function withdrawFor(address user, uint256 amount) public virtual onlyOwnerOrRoles(ROLE_OPERATOR) {
        _withdrawFor(user, amount);
    }

    function getRewardsFor(address user) public virtual onlyOwnerOrRoles(ROLE_OPERATOR) {
        _getRewardsFor(user);
    }

    function getRewardsFor(address user, address to, RewardHandlerParams memory params) public payable virtual onlyOwnerOrRoles(ROLE_OPERATOR) {
        _getRewardsFor(user, to, params);
    }

    function exitFor(address user) public virtual onlyOwnerOrRoles(ROLE_OPERATOR) {
        _exitFor(user);
    }

    function exitFor(address user, address to, RewardHandlerParams memory params) public payable virtual onlyOwnerOrRoles(ROLE_OPERATOR) {
        _exitFor(user, to, params);
    }

    function notifyRewardAmount(address rewardToken, uint256 amount) external onlyOwnerOrRoles(ROLE_OPERATOR | ROLE_REWARD_DISTRIBUTOR) {
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

    function _getRewardsFor(address user) internal {
        _updateRewards(user);

        for (uint256 i; i < rewardTokens.length; ) {
            address rewardToken = rewardTokens[i];
            uint256 reward = rewards[user][rewardToken];

            if (reward > 0) {
                rewards[user][rewardToken] = 0;
                rewardToken.safeTransfer(user, reward);
                emit LogRewardPaid(user, rewardToken, reward);
            }

            unchecked {
                ++i;
            }
        }
    }

    function _getRewardsFor(address user, address to, RewardHandlerParams memory params) internal {
        _updateRewards(user);

        TokenAmount[] memory _rewards = new TokenAmount[](rewardTokens.length);

        for (uint256 i; i < rewardTokens.length; ) {
            address rewardToken = rewardTokens[i];
            uint256 reward = rewards[user][rewardToken];

            rewards[user][rewardToken] = 0;
            rewardToken.safeTransfer(address(rewardHandler), reward);
            _rewards[i] = TokenAmount(rewardToken, reward);
            emit LogRewardPaid(user, rewardToken, reward);

            unchecked {
                ++i;
            }
        }

        rewardHandler.notifyRewards{value: params.value}(user, to, _rewards, params.data);
    }

    function _stakeFor(address user, uint256 amount) internal {
        if (amount == 0) {
            revert ErrZeroAmount();
        }

        _updateRewards(user);
        totalSupply += amount;
        balanceOf[user] += amount;

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit LogStaked(user, amount);
    }

    function _withdrawFor(address user, uint256 amount) internal {
        if (amount == 0) {
            revert ErrZeroAmount();
        }

        _updateRewards(user);
        totalSupply -= amount;
        balanceOf[user] -= amount;

        stakingToken.safeTransfer(user, amount);
        emit LogWithdrawn(user, amount);
    }

    function _exitFor(address user) internal {
        _withdrawFor(user, balanceOf[user]);
        _getRewardsFor(user);
    }

    function _exitFor(address user, address to, RewardHandlerParams memory params) internal {
        _withdrawFor(user, balanceOf[user]);
        _getRewardsFor(user, to, params);
    }

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
