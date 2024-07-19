// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {Owned} from "@solmate/auth/Owned.sol";

interface IRewardHandler {
    function handle(address _token, address _user, uint256 _amount) external payable;
}

/**
 * @title Magic Spell Staking
 * @author 0xMerlin
 * @author Inspired by Stable Joe Staking which in turn is derived from the SushiSwap MasterChef contract
 */
abstract contract MSpellStakingBase {
    using SafeTransferLib for address;

    event LockUpToggled(bool status);
    event RewardHandlerSet(address rewardHandler);

    error ErrUnsupportedOperation();
    error ErrNotStakingOperator();
    error ErrZeroAddress();

    /// @notice Info of each user
    struct UserInfo {
        uint128 amount;
        uint128 rewardDebt;
        uint128 lastAdded;
        /**
         * @notice We do some fancy math here. Basically, any point in time, the amount of JOEs
         * entitled to a user but is pending to be distributed is:
         *
         *   pending reward = (user.amount * accRewardPerShare) - user.rewardDebt[token]
         *
         * Whenever a user deposits or withdraws SPELL. Here's what happens:
         *   1. accRewardPerShare (and `lastRewardBalance`) gets updated
         *   2. User receives the pending reward sent to his/her address
         *   3. User's `amount` gets updated
         *   4. User's `rewardDebt[token]` gets updated
         */
    }

    address public immutable spell;

    /// @notice Array of tokens that users can claim
    address public immutable mim;

    /// @notice Last reward balance of `token`
    uint256 public lastRewardBalance;

    /// @notice amount of time that the position is locked for.
    uint256 private constant LOCK_TIME = 24 hours;
    bool public toggleLockup;

    /// @notice Accumulated `token` rewards per share, scaled to `ACC_REWARD_PER_SHARE_PRECISION`
    uint256 public accRewardPerShare;

    /// @notice The precision of `accRewardPerShare`
    uint256 public constant ACC_REWARD_PER_SHARE_PRECISION = 1e24;

    /// @dev Info of each user that stakes SPELL
    mapping(address => UserInfo) public userInfo;

    /// @notice Emitted when a user deposits SPELL
    event Deposit(address indexed user, uint256 amount);

    /// @notice Emitted when a user withdraws SPELL
    event Withdraw(address indexed user, uint256 amount);

    /// @notice Emitted when a user claims reward
    event ClaimReward(address indexed user, uint256 amount);

    /// @notice Emitted when a user emergency withdraws its SPELL
    event EmergencyWithdraw(address indexed user, uint256 amount);

    IRewardHandler public rewardHandler;

    modifier onlyStakingOperator() {
        if (msg.sender != stakingOperator()) {
            revert ErrNotStakingOperator();
        }
        _;
    }

    /**
     * @notice Initialize a new mSpellStaking contract
     * @dev This contract needs to receive an ERC20 `_rewardToken` in order to distribute them
     * (with MoneyMaker in our case)
     * @param _mim The address of the MIM token
     * @param _spell The address of the SPELL token
     */
    constructor(address _mim, address _spell) {
        if (_mim == address(0) || _spell == address(0)) {
            revert ErrZeroAddress();
        }

        mim = _mim;
        spell = _spell;
        toggleLockup = true;
    }

    /**
     * @notice Deposit SPELL for reward token allocation
     * @param _amount The amount of SPELL to deposit
     */
    function deposit(uint256 _amount) external payable {
        UserInfo storage user = userInfo[msg.sender];

        uint256 _previousAmount = user.amount;
        uint256 _newAmount = user.amount + _amount;
        user.amount = uint128(_newAmount);
        user.lastAdded = uint128(block.timestamp);

        updateReward();

        uint256 _previousRewardDebt = user.rewardDebt;
        user.rewardDebt = uint128((_newAmount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION);

        if (_previousAmount != 0) {
            uint256 _pending = (_previousAmount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION - _previousRewardDebt;
            if (_pending != 0) {
                _claimRewards(mim, msg.sender, _pending, msg.value);
            }
        }

        spell.safeTransferFrom(msg.sender, address(this), _amount);
        _afterDeposit(msg.sender, _amount);

        emit Deposit(msg.sender, _amount);
    }

    /**
     * @notice View function to see pending reward token on frontend
     * @param _user The address of the user
     * @return `_user`'s pending reward token
     */
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 _totalSpell = spell.balanceOf(address(this));
        uint256 _accRewardTokenPerShare = accRewardPerShare;

        uint256 _rewardBalance = mim.balanceOf(address(this));

        if (_rewardBalance != lastRewardBalance && _totalSpell != 0) {
            uint256 _accruedReward = _rewardBalance - lastRewardBalance;
            _accRewardTokenPerShare = _accRewardTokenPerShare + (_accruedReward * ACC_REWARD_PER_SHARE_PRECISION) / _totalSpell;
        }
        return (user.amount * _accRewardTokenPerShare) / ACC_REWARD_PER_SHARE_PRECISION - user.rewardDebt;
    }

    /**
     * @notice Withdraw SPELL and harvest the rewards
     * @param _amount The amount of SPELL to withdraw
     */
    function withdraw(uint256 _amount) external payable {
        UserInfo storage user = userInfo[msg.sender];

        require(!toggleLockup || user.lastAdded + LOCK_TIME < block.timestamp, "mSpell: Wait for LockUp");

        uint256 _previousAmount = user.amount;
        uint256 _newAmount = user.amount - _amount;
        user.amount = uint128(_newAmount);

        updateReward();

        uint256 _pending = (_previousAmount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION - user.rewardDebt;
        user.rewardDebt = uint128((_newAmount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION);

        if (_pending != 0) {
            _claimRewards(mim, msg.sender, _pending, msg.value);
        }

        spell.safeTransfer(msg.sender, _amount);
        _afterWithdraw(msg.sender, _amount);

        emit Withdraw(msg.sender, _amount);
    }

    /**
     * @notice Withdraw without caring about rewards. EMERGENCY ONLY
     */
    function emergencyWithdraw() external {
        UserInfo storage user = userInfo[msg.sender];

        require(!toggleLockup || user.lastAdded + LOCK_TIME < block.timestamp, "mSpell: Wait for LockUp");

        uint256 _amount = user.amount;

        user.amount = 0;
        user.rewardDebt = 0;

        spell.safeTransfer(msg.sender, _amount);
        _afterWithdraw(msg.sender, _amount);

        emit EmergencyWithdraw(msg.sender, _amount);
    }

    /**
     * @notice Update reward variables
     * @dev Needs to be called before any deposit or withdrawal
     */
    function updateReward() public {
        uint256 _rewardBalance = mim.balanceOf(address(this));
        uint256 _totalSpell = spell.balanceOf(address(this));

        // Did mSpellStaking receive any token
        if (_rewardBalance == lastRewardBalance || _totalSpell == 0) {
            return;
        }

        uint256 _accruedReward = _rewardBalance - lastRewardBalance;

        accRewardPerShare = accRewardPerShare + (_accruedReward * ACC_REWARD_PER_SHARE_PRECISION) / _totalSpell;
        lastRewardBalance = _rewardBalance;
    }

    /**
     * @notice Safe token transfer function, just in case if rounding error
     * causes pool to not have enough reward tokens
     * @param _token The address of then token to transfer
     * @param _to The address that will receive `_amount` `rewardToken`
     * @param _amount The amount to send to `_to`
     * @param _value eth value to pass to reward handler
     */
    function _claimRewards(address _token, address _to, uint256 _amount, uint256 _value) internal {
        uint256 _rewardBalance = _token.balanceOf(address(this));

        if (_amount > _rewardBalance) {
            _amount = _rewardBalance;
        }

        lastRewardBalance -= _amount;

        if (rewardHandler != IRewardHandler(address(0))) {
            _token.safeTransfer(address(rewardHandler), _amount);
            rewardHandler.handle{value: _value}(mim, _to, _amount);
        } else {
            _token.safeTransfer(_to, _amount);
        }

        emit ClaimReward(msg.sender, _amount);
    }

    /**
     * @notice Allows to enable and disable the lockup
     * @param status The new lockup status
     */
    function setToggleLockUp(bool status) external onlyStakingOperator {
        toggleLockup = status;

        emit LockUpToggled(status);
    }

    function setRewardHandler(address _rewardHandler) external onlyStakingOperator {
        rewardHandler = IRewardHandler(_rewardHandler);

        emit RewardHandlerSet(_rewardHandler);
    }

    function _afterDeposit(address _user, uint256 _amount) internal virtual {}

    function _afterWithdraw(address _user, uint256 _amount) internal virtual {}

    function stakingOperator() public view virtual returns (address);
}

/// @notice Default implementation of MSpellStaking with an owner as the staking operator
contract MSpellStaking is MSpellStakingBase, Owned {
    constructor(address _mim, address _spell, address _owner) MSpellStakingBase(_mim, _spell) Owned(_owner) {}

    function stakingOperator() public view override returns (address) {
        return owner;
    }
}
