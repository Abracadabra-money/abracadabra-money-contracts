// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@solady/utils/UUPSUpgradeable.sol";

struct UserInfo {
    uint128 amount;
    uint128 rewardDebt;
    uint256 rewards;
}

contract SimpleStaking is OwnableRoles {
    using SafeTransferLib for address;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, address indexed to, uint256 amount);
    event ClaimReward(address indexed user, address indexed to, uint256 amount);

    error ErrZeroAddress();

    // ROLES
    uint256 public constant ROLE_OPERATOR = _ROLE_0;
    uint256 public constant ROLE_REWARD_DISTRIBUTOR = _ROLE_1;

    uint256 public constant ACC_REWARD_PER_SHARE_PRECISION = 1e24;

    address public immutable stakingToken;
    address public immutable rewardToken;

    uint256 public totalStaked;
    uint256 public totalRewards;
    uint256 public lastRewardBalance;
    uint256 public accRewardPerShare;

    mapping(address => UserInfo) public userInfo;

    constructor(address _stakingToken, address _rewardToken) {
        if (_stakingToken == address(0) || _rewardToken == address(0)) {
            revert ErrZeroAddress();
        }

        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
    }

    //////////////////////////////////////////////////////////////////////////////////
    // Permissionless
    //////////////////////////////////////////////////////////////////////////////////

    function deposit(uint256 amount) external {
        _depositFor(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        _withdrawFor(msg.sender, msg.sender, amount);
    }

    function claimReward(address to) external {
        _getRewardsFor(msg.sender, to);
    }

    //////////////////////////////////////////////////////////////////////////////////
    // Views
    //////////////////////////////////////////////////////////////////////////////////

    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 _accRewardTokenPerShare = accRewardPerShare;

        if (totalRewards != lastRewardBalance && totalStaked != 0) {
            uint256 _accruedReward = totalRewards - lastRewardBalance;
            _accRewardTokenPerShare = _accRewardTokenPerShare + (_accruedReward * ACC_REWARD_PER_SHARE_PRECISION) / totalStaked;
        }

        return (user.amount * _accRewardTokenPerShare) / ACC_REWARD_PER_SHARE_PRECISION - user.rewardDebt;
    }

    //////////////////////////////////////////////////////////////////////////////////
    // Operators
    //////////////////////////////////////////////////////////////////////////////////

    function notifyRewards(uint256 _amount) public onlyOwnerOrRoles(ROLE_OPERATOR | ROLE_REWARD_DISTRIBUTOR) {
        if (totalStaked == 0 || _amount == 0) {
            return;
        }

        rewardToken.safeTransferFrom(msg.sender, address(this), _amount);
        totalRewards += _amount;

        _updateReward();
    }

    //////////////////////////////////////////////////////////////////////////////////
    // Internals
    //////////////////////////////////////////////////////////////////////////////////

    function _depositFor(address _user, uint256 _amount) public payable virtual {
        _updateReward();

        UserInfo storage user = userInfo[_user];
        uint256 _previousAmount = user.amount;
        uint256 _newAmount = _previousAmount + _amount;

        _updateUserInfo(user, _previousAmount, _newAmount);

        totalStaked += _amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(_user, _amount);
    }

    function _withdrawFor(address _user, address _to, uint256 _amount) internal {
        _updateReward();

        UserInfo storage user = userInfo[_user];
        uint256 _previousAmount = user.amount;
        uint256 _newAmount = _previousAmount - _amount;

        _updateUserInfo(user, _previousAmount, _newAmount);

        totalStaked -= _amount;
        stakingToken.safeTransfer(_to, _amount);

        emit Withdraw(_user, _to, _amount);
    }

    function _updateUserInfo(UserInfo storage user, uint256 _previousAmount, uint256 _newAmount) internal {
        uint256 _previousRewardDebt = user.rewardDebt;

        user.amount = uint128(_newAmount);
        user.rewardDebt = uint128((_newAmount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION);

        if (_previousAmount != 0) {
            uint256 rewardsAmount = (_previousAmount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION - _previousRewardDebt;
            if (rewardsAmount > 0) {
                user.rewards += rewardsAmount;
                lastRewardBalance -= _previousAmount > _newAmount ? _previousAmount - _newAmount : _newAmount - _previousAmount;
            }
        }
    }

    function _getRewardsFor(address _user, address _to) internal {
        UserInfo storage user = userInfo[_user];
        uint256 _rewardsToClaim = user.rewards;

        if (_rewardsToClaim == 0) {
            return;
        }

        userInfo[_user].rewards = 0;
        totalRewards -= _rewardsToClaim;
        rewardToken.safeTransfer(_to, _rewardsToClaim);

        emit ClaimReward(_user, _to, _rewardsToClaim);
    }

    function _updateReward() internal {
        uint256 _accruedReward = totalRewards - lastRewardBalance;

        accRewardPerShare += (_accruedReward * ACC_REWARD_PER_SHARE_PRECISION) / totalStaked;
        lastRewardBalance = totalRewards;
    }
}

contract UpgradeableSimpleStaking is SimpleStaking, UUPSUpgradeable, Initializable {
    constructor(address _stakingToken, address _rewardToken) SimpleStaking(_stakingToken, _rewardToken) {}

    function initialize(address _owner) external initializer {
        _initializeOwner(_owner);
    }

    function _authorizeUpgrade(address /*newImplementation*/) internal virtual override {
        _checkOwner();
    }
}

contract PermissionedUpgradeableSimpleStaking is OwnableRoles, UUPSUpgradeable, Initializable {
    uint256 public constant ROLE_OPERATOR = _ROLE_0;

    constructor() UUPSUpgradeable() {}

    function initialize(address _owner) external initializer {
        _initializeOwner(_owner);
    }

    function _authorizeUpgrade(address /*newImplementation*/) internal virtual override {
        _checkOwner();
    }
}
