// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {Owned} from "@solmate/auth/Owned.sol";

interface IRewardHandler {
    function handle(address _token, address _user, uint256 _amount) external payable;
}

struct UserInfo {
    uint128 amount;
    uint128 rewardDebt;
    uint128 lastAdded;
    uint128 claimableRewards;
}

/**
 * @title Magic Spell Staking
 * @author 0xMerlin
 * @author Inspired by Stable Joe Staking which in turn is derived from the SushiSwap MasterChef contract
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
        lockupEnabled = true;
    }

    function deposit(uint256 _amount) external payable {
        _updateReward();

        UserInfo storage user = userInfo[msg.sender];
        uint256 _previousAmount = user.amount;
        uint256 _previousRewardDebt = user.rewardDebt;
        uint256 _newAmount = _previousAmount + _amount;

        user.amount = uint128(_newAmount);
        user.lastAdded = uint128(block.timestamp);
        user.rewardDebt = uint128((_newAmount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION);

        if (_previousAmount != 0) {
            user.claimableRewards += uint128((_previousAmount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION - _previousRewardDebt);
        }

        spell.safeTransferFrom(msg.sender, address(this), _amount);
        _afterDeposit(msg.sender, _amount);

        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external payable {
        UserInfo storage user = userInfo[msg.sender];
        _checkLockup(user);
        _updateReward();

        uint256 _previousAmount = user.amount;
        uint256 _newAmount = _previousAmount - _amount;
        uint256 _pending = (_previousAmount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION - user.rewardDebt;

        user.amount = uint128(_newAmount);
        user.rewardDebt = uint128((_newAmount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION);

        if (_pending != 0) {
            _claimRewards(mim, msg.sender, _pending);
        }

        spell.safeTransfer(msg.sender, _amount);
        _afterWithdraw(msg.sender, _amount);

        emit Withdraw(msg.sender, _amount);
    }

    function emergencyWithdraw() external {
        UserInfo storage user = userInfo[msg.sender];
        _checkLockup(user);

        uint256 _amount = user.amount;

        user.amount = 0;
        user.rewardDebt = 0;
        user.claimableRewards = 0;
        
        spell.safeTransfer(msg.sender, _amount);
        _afterWithdraw(msg.sender, _amount);

        emit EmergencyWithdraw(msg.sender, _amount);
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

    function _updateReward() internal {
        uint256 _rewardBalance = mim.balanceOf(address(this));
        uint256 _totalSpell = spell.balanceOf(address(this));

        if (_rewardBalance == lastRewardBalance || _totalSpell == 0) {
            return;
        }

        uint256 _accruedReward = _rewardBalance - lastRewardBalance;

        accRewardPerShare += (_accruedReward * ACC_REWARD_PER_SHARE_PRECISION) / _totalSpell;
        lastRewardBalance = _rewardBalance;
    }

    function _claimRewards(address _token, address _to, uint256 _amount) internal {
        uint256 _rewardBalance = _token.balanceOf(address(this));

        if (_amount > _rewardBalance) {
            _amount = _rewardBalance;
        }

        lastRewardBalance -= _amount;

        if (rewardHandler != IRewardHandler(address(0))) {
            _token.safeTransfer(address(rewardHandler), _amount);
            rewardHandler.handle{value: msg.value}(mim, _to, _amount);
        } else {
            _token.safeTransfer(_to, _amount);
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

    function _afterDeposit(address _user, uint256 _amount) internal virtual;

    function _afterWithdraw(address _user, uint256 _amount) internal virtual;
}

/// @notice Default implementation of MSpellStaking
contract MSpellStaking is MSpellStakingBase, Owned {
    constructor(address _mim, address _spell, address _owner) MSpellStakingBase(_mim, _spell) Owned(_owner) {}

    function setToggleLockUp(bool status) external onlyOwner {
        _setLockupEnabled(status);
    }

    function setRewardHandler(address _rewardHandler) external onlyOwner {
        _setRewardHandler(_rewardHandler);
    }

    function _afterDeposit(address _user, uint256 _amount) internal override {}

    function _afterWithdraw(address _user, uint256 _amount) internal override {}
}
