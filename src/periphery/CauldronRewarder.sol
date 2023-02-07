// SPDX-License-Identifier: MIT
// Inspired by Stable Joe Staking which in turn is derived from the SushiSwap MasterChef contract
// adapted from mSpell

pragma solidity >=0.8.0;

import "BoringSolidity/libraries/BoringERC20.sol";
import "BoringSolidity/libraries/BoringRebase.sol";
import "interfaces/ICauldronV4.sol";
import "interfaces/ICauldronRewarder.sol";
import "interfaces/IBentoBoxV1.sol";

/**
 * @title CauldronRewarder
 * @author 0xMerlin
 */
contract CauldronRewarder is ICauldronRewarder {
    using BoringERC20 for IERC20;
    using RebaseLibrary for Rebase;

    /// @notice Emitted when a user deposits a cauldron collateral
    event Deposit(address indexed user, uint256 amount);
    /// @notice Emitted when a user withdraws a cauldron collateral
    event Withdraw(address indexed user, uint256 amount);
    /// @notice Emitted when a user claims reward
    event ClaimReward(address indexed user, uint256 amount);

    error ErrInvalidReward();
    error ErrNotCauldron();

    /// @notice Info of each user
    struct UserInfo {
        uint256 amount; // in this case, the deposited collateral share.
        int256 rewardDebt;
    }

    /// @notice The precision of `accRewardPerShare`
    uint256 public constant ACC_REWARD_PER_SHARE_PRECISION = 1e24;

    IBentoBoxV1 public immutable degenBox;
    ICauldronV4 public immutable cauldron;

    /// @notice The reward that users can claim
    IERC20 public immutable mim;

    /// @notice Last mim reward balance
    uint256 public lastRewardBalance;

    /// @notice Accumulated mim rewards per share, scaled to `ACC_REWARD_PER_SHARE_PRECISION`
    uint256 public accRewardPerShare;

    /// @dev Info of each user that stakes a cauldron collateral
    mapping(address => UserInfo) public userInfo;

    /**
     * @notice Initialize a new Rewarder contract
     * @dev This contract needs to receive mim tokens in order to distribute them
     */
    constructor(IERC20 _mim, ICauldronV4 _cauldron) {
        if (address(_mim) == address(0)) {
            revert ErrInvalidReward();
        }

        mim = _mim;
        cauldron = _cauldron;
        degenBox = IBentoBoxV1(_cauldron.bentoBox());
    }

    modifier onlyCauldron() {
        if (msg.sender != address(cauldron)) {
            revert ErrNotCauldron();
        }
        _;
    }

    /**
     * @notice Deposit cauldron collateral for reward token allocation
     * @param _collateralShare The amount of cauldron collateral share to deposit
     */
    function deposit(address _from, uint256 _collateralShare) external override onlyCauldron {
        UserInfo storage user = userInfo[_from];
        user.amount += _collateralShare;

        updateReward();
        user.rewardDebt += int256((_collateralShare * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION);

        emit Deposit(_from, _collateralShare);
    }

    /**
     * @notice View function to see pending reward token
     * @param _user The address of the user
     * @return `_user`'s pending reward token
     */
    function pendingReward(address _user) external view override returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 _totalCollateral = cauldron.totalCollateralShare();
        uint256 _accRewardPerShare = accRewardPerShare;
        uint256 _rewardBalance = degenBox.balanceOf(mim, address(this));

        if (_rewardBalance != lastRewardBalance && _totalCollateral != 0) {
            uint256 _accruedReward = _rewardBalance - lastRewardBalance;
            _accRewardPerShare += (_accruedReward * ACC_REWARD_PER_SHARE_PRECISION) / _totalCollateral;
        }

        return uint256(int256((user.amount * _accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION) - user.rewardDebt);
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
        bool repay
    )
        internal
        returns (
            UserInfo memory,
            uint256 share,
            uint256 part,
            uint256 overshoot
        )
    {
        int256 accumulatedMim = int256((user.amount * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION);
        uint256 pendingRewards = uint256(accumulatedMim - user.rewardDebt);

        user.rewardDebt = accumulatedMim;

        if (pendingRewards != 0) {
            uint256 borrowPart = cauldron.userBorrowPart(to);
            Rebase memory totalBorrow = cauldron.totalBorrow();

            // Total debt (borrowed + interests)
            uint256 elastic = totalBorrow.toElastic(borrowPart, true);

            /// @dev deposited amount is cauldron collateral share, and the pendingRewards are
            /// calculated based on share, so we need to convert to amount.
            uint256 pendingRewardsAmount = degenBox.toAmount(mim, pendingRewards, false);

            // pending rewards doesn't cover all debts
            if (elastic >= pendingRewardsAmount) {
                part = totalBorrow.toBase(pendingRewardsAmount, false);
                share = pendingRewards;

                if (repay) {
                    _repayLoan(to, pendingRewards, part);
                }
            }
            // there's more rewards than debts left. take
            // what's
            else {
                share = degenBox.toShare(mim, elastic, true);
                part = borrowPart;

                if (repay) {
                    _repayLoan(to, share, borrowPart);
                }

                overshoot = pendingRewards - share;
                degenBox.transfer(mim, address(this), to, overshoot);
            }
            lastRewardBalance -= pendingRewards;
        }

        emit ClaimReward(to, pendingRewards);

        return (user, share, part, overshoot);
    }

    /**
     * @notice Withdraw collateral share and harvest the rewards
     * @param from user for which amount is withdrawn
     * @param _collateralShare The collateral share to withdraw
     */
    function withdraw(address from, uint256 _collateralShare) external override onlyCauldron {
        UserInfo storage user = userInfo[from];
        user.amount -= _collateralShare;

        updateReward();

        user.rewardDebt -= int256((_collateralShare * accRewardPerShare) / ACC_REWARD_PER_SHARE_PRECISION);
        emit Withdraw(msg.sender, _collateralShare);
    }

    function harvest(address to) public override returns (uint256 overshoot) {
        UserInfo memory user = userInfo[to];
        cauldron.accrue();

        updateReward();

        (userInfo[to], , , overshoot) = _harvest(user, to, true);
    }

    /// @dev Does not call accrue
    function harvestMultiple(address[] calldata to) external override {
        updateReward();
        uint256 totalShare;
        uint256[] memory parts = new uint256[](to.length);

        for (uint256 i; i < to.length; i++) {
            UserInfo memory user = userInfo[to[i]];
            uint256 share;
            uint256 part;
            (userInfo[to[i]], share, part, ) = _harvest(user, to[i], false);
            totalShare += share;
            parts[i] = part;
        }

        degenBox.transfer(mim, address(this), address(degenBox), totalShare);

        for (uint256 i; i < to.length; i++) {
            if (parts[i] != 0) {
                cauldron.repay(to[i], true, parts[i]);
            }
        }
    }

    /**
     * @notice Update reward variables
     * @dev Needs to be called before any deposit or withdrawal
     */
    function updateReward() public {
        uint256 _rewardBalance = degenBox.balanceOf(mim, address(this));
        uint256 _totalCollateralShare = cauldron.totalCollateralShare();

        // No new rewards or deposited collateral yet.
        if (_rewardBalance == lastRewardBalance || _totalCollateralShare == 0) {
            return;
        }

        uint256 _accruedReward = _rewardBalance - lastRewardBalance;

        accRewardPerShare += (_accruedReward * ACC_REWARD_PER_SHARE_PRECISION) / _totalCollateralShare;
        lastRewardBalance = _rewardBalance;
    }

    function updateReward(IERC20) public override {
        updateReward();
    }
}
