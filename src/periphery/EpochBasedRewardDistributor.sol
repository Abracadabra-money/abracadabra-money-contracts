// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {OperatableV2} from "mixins/OperatableV2.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

interface IEpochBasedStaking {
    function epoch() external view returns (uint256);

    function notifyRewardAmount(address rewardToken, uint256 amount, uint minRemainingTime) external;
}

contract EpochBasedRewardDistributor is OperatableV2 {
    using SafeTransferLib for address;
    
    event LogRewardSet(address indexed reward, uint256 amount);
    event LogWithdraw(address indexed token, address indexed to, uint256 amount);
    event LogDistributed(uint256 epoch);

    error ErrNotReady();

    address public immutable staking;

    uint256 public lastEpoch;
    address[] public rewards;
    mapping(address => uint256) public amount;
    uint256 public minRemainingTime;

    constructor(address _staking, uint256 _minRemainingTime, address _owner) OperatableV2(_owner) {
        staking = _staking;
        minRemainingTime = _minRemainingTime;
    }

    function ready() public view returns (bool) {
        return lastEpoch < IEpochBasedStaking(staking).epoch();
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    ////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Set reward token and amount distributed on each epoch
    /// @param _reward Reward token address
    /// @param _amount Reward amount, use 0 to remove
    function setReward(address _reward, uint256 _amount) external onlyOwner {
        for (uint256 i = 0; i < rewards.length; i++) {
            if (rewards[i] == _reward) {
                rewards[i] = rewards[rewards.length - 1];
                rewards.pop();
                break;
            }
        }

        if (_amount > 0) {
            rewards.push(_reward);
        }
        amount[_reward] = _amount;

        emit LogRewardSet(_reward, _amount);
    }

    function withdraw(address _token, address _to, uint256 _amount) external onlyOwner {
        _token.safeTransfer(_to, _amount);
        emit LogWithdraw(_token, _to, _amount);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function distributeRewards(address _staking) external onlyOperators {
        if(!ready()) {
            revert ErrNotReady();
        }

        for (uint256 i = 0; i < rewards.length; i++) {
            address reward = rewards[i];
            uint256 rewardAmount = amount[reward];
            IEpochBasedStaking(_staking).notifyRewardAmount(reward, rewardAmount, minRemainingTime);
        }

        lastEpoch = IEpochBasedStaking(_staking).epoch();
        emit LogDistributed(lastEpoch);
    }
    
}
