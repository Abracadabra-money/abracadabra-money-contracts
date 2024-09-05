// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {Owned} from "@solmate/auth/Owned.sol";

interface IRewardHandler {
    function notifyRewards(address _user, address _token, uint256 _amount, bytes memory _data) external payable;
}

struct UserInfo {
    uint128 amount;
    uint128 rewardDebt;
    uint256 lastAdded;
}

struct RewardHandlerParams {
    bytes data;
    uint256 value;
}

/**
 * @title Magic Spell Staking
 * @author Inspired by Stable Joe Staking which in turn is derived from the SushiSwap MasterChef contract
 * @notice When a reward handler is used, the contract will transfer the reward tokens to the reward handler
 * for custom processing, like immediate or postponed cross-chain transfers, otherwise directly to the users.
 */
abstract contract MSpellStakingBase {
    using SafeTransferLib for address;

    event LockupEnabled(bool status);
    event RewardHandlerSet(address rewardHandler);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event ClaimReward(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    error ErrZeroAddress();
    error ErrLockedUp();

    uint256 public constant ACC_REWARD_PER_SHARE_PRECISION = 1e24;
    uint256 public constant LOCK_TIME = 24 hours;

    address public immutable spell;
    address public immutable mim;

    uint256 public lastRewardBalance;
    uint256 public accRewardPerShare;
    bool public lockupEnabled;
    IRewardHandler public rewardHandler;

    mapping(address => UserInfo) public userInfo;

    constructor(address _mim, address _spell) {
        if (_mim == address(0) || _spell == address(0)) {
            revert ErrZeroAddress();
        }

        mim = _mim;
        spell = _spell;
    }

    function deposit(uint256 _amount) external payable {
        deposit(_amount, RewardHandlerParams({data: "", value: 0}));
    }

    function withdraw(uint256 _amount) external payable {
        withdraw(_amount, RewardHandlerParams({data: "", value: 0}));
    }

    function deposit(uint256 _amount, RewardHandlerParams memory _rewardHandlerParams) public payable {
        updateReward();

        UserInfo storage user = userInfo[msg.sender];

        uint256 _previousAmount = user.amount;
        uint256 _previousRewardDebt = user.rewardDebt;
        uint256 _newAmount = _previousAmount + _amount;

        user.amount = uint128(_newAmount);
        user.rewardDebt = uint128((_newAmount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION);
        user.lastAdded = block.timestamp;

        if (_previousAmount != 0) {
            uint256 rewardsAmount = (_previousAmount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION - _previousRewardDebt;
            if (rewardsAmount > 0) {
                _claimRewards(msg.sender, rewardsAmount, _rewardHandlerParams);
            }
        }

        spell.safeTransferFrom(msg.sender, address(this), _amount);
        _afterDeposit(msg.sender, _amount, msg.value - _rewardHandlerParams.value);

        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount, RewardHandlerParams memory _rewardHandlerParams) public payable {
        updateReward();

        UserInfo storage user = userInfo[msg.sender];
        _checkLockup(user);

        uint256 _previousAmount = user.amount;
        uint256 _previousRewardDebt = user.rewardDebt;
        uint256 _newAmount = _previousAmount - _amount;

        user.amount = uint128(_newAmount);
        user.rewardDebt = uint128((_newAmount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION);

        if (_previousAmount != 0) {
            uint256 rewardsAmount = (_previousAmount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION - _previousRewardDebt;
            if (rewardsAmount > 0) {
                _claimRewards(msg.sender, rewardsAmount, _rewardHandlerParams);
            }
        }

        spell.safeTransfer(msg.sender, _amount);
        _afterWithdraw(msg.sender, _amount, msg.value - _rewardHandlerParams.value);

        emit Withdraw(msg.sender, _amount);
    }

    function updateReward() public {
        uint256 _rewardBalance = mim.balanceOf(address(this));
        uint256 _totalSpell = spell.balanceOf(address(this));

        if (_rewardBalance == lastRewardBalance || _totalSpell == 0) {
            return;
        }

        uint256 _accruedReward = _rewardBalance - lastRewardBalance;

        accRewardPerShare += (_accruedReward * ACC_REWARD_PER_SHARE_PRECISION) / _totalSpell;
        lastRewardBalance = _rewardBalance;
    }

    //////////////////////////////////////////////////////////////////////////////////
    // Views
    //////////////////////////////////////////////////////////////////////////////////

    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 _totalSpell = spell.balanceOf(address(this));
        uint256 _rewardBalance = mim.balanceOf(address(this));
        uint256 _accRewardTokenPerShare = accRewardPerShare;

        if (_rewardBalance != lastRewardBalance && _totalSpell != 0) {
            uint256 _accruedReward = _rewardBalance - lastRewardBalance;
            _accRewardTokenPerShare = _accRewardTokenPerShare + (_accruedReward * ACC_REWARD_PER_SHARE_PRECISION) / _totalSpell;
        }

        return (user.amount * _accRewardTokenPerShare) / ACC_REWARD_PER_SHARE_PRECISION - user.rewardDebt;
    }

    //////////////////////////////////////////////////////////////////////////////////
    // Internals
    //////////////////////////////////////////////////////////////////////////////////

    function _checkLockup(UserInfo storage user) internal view {
        if (lockupEnabled && user.lastAdded + LOCK_TIME > block.timestamp) {
            revert ErrLockedUp();
        }
    }

    function _claimRewards(address _to, uint256 _amount, RewardHandlerParams memory _rewardHandlerParams) internal {
        uint256 _rewardBalance = mim.balanceOf(address(this));

        if (_amount > _rewardBalance) {
            _amount = _rewardBalance;
        }

        lastRewardBalance -= _amount;

        if (rewardHandler != IRewardHandler(address(0))) {
            mim.safeTransfer(address(rewardHandler), _amount);
            rewardHandler.notifyRewards{value: _rewardHandlerParams.value}(_to, mim, _amount, _rewardHandlerParams.data);
        } else {
            mim.safeTransfer(_to, _amount);
        }

        emit ClaimReward(msg.sender, _amount);
    }

    function _setLockupEnabled(bool enabled) internal {
        lockupEnabled = enabled;
        emit LockupEnabled(enabled);
    }

    function _setRewardHandler(address _rewardHandler) internal {
        rewardHandler = IRewardHandler(_rewardHandler);
        emit RewardHandlerSet(_rewardHandler);
    }

    function _afterDeposit(address _user, uint256 _amount, uint256 _value) internal virtual;

    function _afterWithdraw(address _user, uint256 _amount, uint256 _value) internal virtual;
}

/// @notice Default implementation of MSpellStaking
contract MSpellStaking is MSpellStakingBase, Owned {
    constructor(address _mim, address _spell, address _owner) MSpellStakingBase(_mim, _spell) Owned(_owner) {
        _setLockupEnabled(true);
    }

    function setToggleLockUp(bool status) external onlyOwner {
        _setLockupEnabled(status);
    }

    function setRewardHandler(address _rewardHandler) external onlyOwner {
        _setRewardHandler(_rewardHandler);
    }

    function _afterDeposit(address _user, uint256 _amount, uint256 _value) internal override {}

    function _afterWithdraw(address _user, uint256 _amount, uint256 _value) internal override {}
}
