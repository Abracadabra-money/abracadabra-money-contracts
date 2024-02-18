// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {OperatableV2} from "mixins/OperatableV2.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

interface IEpochBasedStaking {
    function epoch() external view returns (uint256);

    function nextEpoch() external view returns (uint256);

    function rewardData(
        address token
    ) external view returns (uint256 periodFinish, uint256 rewardRate, uint256 rewardPerTokenStored, bool exists, uint248 lastUpdateTime);

    function notifyRewardAmount(address rewardToken, uint256 amount, uint minRemainingTime) external;

    function rewardTokensLength() external view returns (uint);

    function rewardTokens(uint index) external view returns (address);
}

/// @notice Distribute rewards to staking contracts based on epochs
/// Amounts deposited to this contract are distributed to staking contracts
/// only on the next epoch
contract EpochBasedRewardDistributor is OperatableV2 {
    using SafeTransferLib for address;

    event LogRewardAdded(address indexed reward, uint256 amount);
    event LogWithdraw(address indexed token, address indexed to, uint256 amount);
    event LogDistributed(uint256 epoch);
    event LogMinRemainingTimeSet(uint256 previous, uint256 current);

    error ErrInvalidRewardToken();
    error ErrNotReady();

    address public immutable staking;

    uint256 public epoch;
    uint256 public minRemainingTime;

    mapping(address => uint256) public balanceOf;

    constructor(address _staking, uint256 _minRemainingTime, address _owner) OperatableV2(_owner) {
        staking = _staking;
        minRemainingTime = _minRemainingTime;
        epoch = IEpochBasedStaking(_staking).nextEpoch();
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function ready() public view returns (bool) {
        return epoch <= IEpochBasedStaking(staking).epoch();
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function deposit(address _token, uint256 _amount) external onlyOperators {
        (, , , bool exists, ) = IEpochBasedStaking(staking).rewardData(_token);
        if (!exists) {
            revert ErrInvalidRewardToken();
        }

        _token.safeTransferFrom(msg.sender, address(this), _amount);
        balanceOf[_token] += _amount;

        _token.safeApprove(staking, balanceOf[_token]);

        emit LogRewardAdded(_token, _amount);
    }

    function distribute() external onlyOperators {
        if (!ready()) {
            revert ErrNotReady();
        }

        uint256 rewardLength = IEpochBasedStaking(staking).rewardTokensLength();

        for (uint256 i = 0; i < rewardLength; i++) {
            address reward = IEpochBasedStaking(staking).rewardTokens(i);
            uint256 rewardAmount = balanceOf[reward];

            delete balanceOf[reward];

            if (rewardAmount > 0) {
                IEpochBasedStaking(staking).notifyRewardAmount(reward, rewardAmount, minRemainingTime);
            }
        }

        epoch = IEpochBasedStaking(staking).nextEpoch();
        emit LogDistributed(epoch);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function withdraw(address _token, address _to, uint256 _amount) external onlyOwner {
        _token.safeTransfer(_to, _amount);
        balanceOf[_token] = _token.balanceOf(address(this));
        emit LogWithdraw(_token, _to, _amount);
    }

    function setMinRemainingTime(uint256 _minRemainingTime) external onlyOwner {
        emit LogMinRemainingTimeSet(minRemainingTime, _minRemainingTime);
        minRemainingTime = _minRemainingTime;
    }
}
