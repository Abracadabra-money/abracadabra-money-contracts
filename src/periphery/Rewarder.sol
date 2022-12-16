// SPDX-License-Identifier: MIT
// Inspired by Stable Joe Staking which in turn is derived from the SushiSwap MasterChef contract
// adapted from mSpell

pragma solidity >=0.8.0;
import "BoringSolidity/libraries/BoringERC20.sol";
import "BoringSolidity/libraries/BoringRebase.sol";

import "interfaces/ICauldronV4.sol";
import "interfaces/IRewarder.sol";
import "interfaces/IBentoBoxV1.sol";

/**
 * @title Rewarder
 * @author 0xMerlin
 */
contract Rewarder is IRewarder {
    using BoringERC20 for IERC20;
    using RebaseLibrary for Rebase;
    /// @notice Info of each user
    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
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
    IBentoBoxV1 public immutable degenBox;
    ICauldronV4 public immutable cauldron;
    /// @notice Array of tokens that users can claim
    IERC20 public immutable mim;
    /// @notice Last reward balance of `token`
    uint256 public lastRewardBalance;

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

    /**
     * @notice Initialize a new mSpellStaking contract
     * @dev This contract needs to receive an IERC20 `_rewardToken` in order to distribute them
     * (with MoneyMaker in our case)
     * @param _mim The address of the MIM token
     */
    constructor(IERC20 _mim, ICauldronV4 _cauldron) {
        require(address(_mim) != address(0), "mSpellStaking: reward token can't be address(0)");

        mim = _mim;
        cauldron = _cauldron;
        degenBox = IBentoBoxV1(_cauldron.bentoBox());
    }

    modifier onlyCauldron() {
        require(msg.sender == address(cauldron), "Caller needs to be Cauldron");
        _;
    }

    /**
     * @notice Deposit SPELL for reward token allocation
     * @param _amount The amount of SPELL to deposit
     */
    function deposit(address from, uint256 _amount) external override onlyCauldron {
        UserInfo storage user = userInfo[from];

        user.amount = user.amount + _amount;

        updateReward();

        user.rewardDebt = user.rewardDebt + int256((_amount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION);

        emit Deposit(from, _amount);
    }

    /**
     * @notice View function to see pending reward token on frontend
     * @param _user The address of the user
     * @return `_user`'s pending reward token
     */
    function pendingReward(address _user) external view override returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 _totalSpell = cauldron.totalCollateralShare();
        uint256 _accRewardTokenPerShare = accRewardPerShare;

        uint256 _rewardBalance = degenBox.balanceOf(mim, address(this));

        if (_rewardBalance != lastRewardBalance && _totalSpell != 0) {
            uint256 _accruedReward = _rewardBalance - lastRewardBalance;
            _accRewardTokenPerShare = _accRewardTokenPerShare + (_accruedReward * ACC_REWARD_PER_SHARE_PRECISION) / _totalSpell;
        }
        return uint256(int256((user.amount * _accRewardTokenPerShare) / ACC_REWARD_PER_SHARE_PRECISION) - user.rewardDebt);
    }

    function _repayLoan(
        address to,
        uint256 share,
        uint256 part
    ) internal {
        degenBox.transfer(mim, address(this), address(degenBox), share);
        cauldron.repay(to, true, part);
    }

    function _harvest(
        UserInfo memory user,
        address to,
        bool multiple
    )
        internal
        returns (
            UserInfo memory,
            uint256 share,
            uint256 part
        )
    {
        int256 accumulatedMim = int256((user.amount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION);
        uint256 pendingRewards = uint256(accumulatedMim - user.rewardDebt);

        user.rewardDebt = accumulatedMim;

        if (pendingRewards != 0) {
            uint256 borrowPart = cauldron.userBorrowPart(to);
            Rebase memory totalBorrow = cauldron.totalBorrow();

            uint256 elastic = totalBorrow.toElastic(borrowPart, true);
            uint256 pendingRewardsAmount = degenBox.toAmount(mim, pendingRewards, false);

            if (elastic >= pendingRewardsAmount) {
                part = totalBorrow.toBase(pendingRewards, false);
                if (multiple) {
                    share = pendingRewards;
                } else {
                    _repayLoan(to, pendingRewards, part);
                }
            } else {
                share = degenBox.toShare(mim, elastic, true);
                if (multiple) {
                    part = borrowPart;
                } else {
                    _repayLoan(to, share, borrowPart);
                }
                degenBox.transfer(mim, address(this), to, pendingRewards - share);
            }
            lastRewardBalance -= pendingRewards;
        }

        emit ClaimReward(to, pendingRewards);

        return (user, share, part);
    }

    /**
     * @notice Withdraw SPELL and harvest the rewards
     * @param from user for which amount is withdrawn
     * @param _amount The amount of SPELL to withdraw
     */
    function withdraw(address from, uint256 _amount) external override onlyCauldron {
        UserInfo storage user = userInfo[from];

        user.amount = user.amount - _amount;

        updateReward();

        user.rewardDebt = user.rewardDebt - int256((_amount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION);

        emit Withdraw(msg.sender, _amount);
    }

    function harvest(address to) public override {
        UserInfo memory user = userInfo[to];

        cauldron.accrue();

        updateReward();

        (userInfo[to], , ) = _harvest(user, to, false);
    }

    // does not call accrue
    function harvestMultiple(address[] calldata to) external override {
        updateReward();
        uint256 totalShare;
        uint256[] memory parts = new uint256[](to.length);
        for (uint256 i; i < to.length; i++) {
            UserInfo memory user = userInfo[to[i]];
            uint256 share;
            uint256 part;
            (userInfo[to[0]], share, part) = _harvest(user, to[i], true);
            totalShare += share;
            parts[i] = part;
        }

        degenBox.transfer(mim, address(this), address(degenBox), totalShare);

        for (uint256 i; i < to.length; i++) {
            if (parts[i] == 0) {
                continue;
            }
            cauldron.repay(to[i], true, parts[i]);
        }
    }

    /**
     * @notice Update reward variables
     * @dev Needs to be called before any deposit or withdrawal
     */
    function updateReward() public {
        uint256 _rewardBalance = degenBox.balanceOf(mim, address(this));
        uint256 _totalSpell = cauldron.totalCollateralShare();

        // Did mSpellStaking receive any token
        if (_rewardBalance == lastRewardBalance || _totalSpell == 0) {
            return;
        }

        uint256 _accruedReward = _rewardBalance - lastRewardBalance;

        accRewardPerShare = accRewardPerShare + (_accruedReward * ACC_REWARD_PER_SHARE_PRECISION) / _totalSpell;
        lastRewardBalance = _rewardBalance;
    }

    function updateReward(IERC20) public override {
        updateReward();
    }
}
