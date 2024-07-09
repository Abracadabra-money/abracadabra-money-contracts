// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IMultiRewardsStaking} from "interfaces/IMultiRewardsStaking.sol";
import {BaseRewardDistributor} from "staking/distributors/BaseRewardDistributor.sol";

/// @notice Distribute rewards to MultiRewards staking contracts
contract MultiRewardDistributor is BaseRewardDistributor {
    using SafeTransferLib for address;

    event LogDistributed();

    constructor(address _vault, address _owner) BaseRewardDistributor(_vault, _owner) {}

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function ready(address _staking) public view override returns (bool) {
        uint256 rewardLength = IMultiRewardsStaking(_staking).getRewardTokenLength();

        for (uint256 i = 0; i < rewardLength; i++) {
            address reward = IMultiRewardsStaking(_staking).rewardTokens(i);
            uint256 rewardAmount = rewardDistributions[_staking][reward];

            if (rewardAmount > 0) {
                if (block.timestamp >= IMultiRewardsStaking(_staking).rewardData(reward).periodFinish) {
                    return true;
                }
            }
        }

        return false;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function _onDistribute(address _staking) internal override {
        uint256 rewardLength = IMultiRewardsStaking(_staking).getRewardTokenLength();

        for (uint256 i = 0; i < rewardLength; i++) {
            address reward = IMultiRewardsStaking(_staking).rewardTokens(i);
            uint256 periodFinish = IMultiRewardsStaking(_staking).rewardData(reward).periodFinish;

            if (block.timestamp >= periodFinish) {
                uint256 rewardAmount = rewardDistributions[_staking][reward];

                if (rewardAmount > 0) {
                    reward.safeTransferFrom(vault, address(this), rewardAmount);
                    IMultiRewardsStaking(_staking).notifyRewardAmount(reward, rewardAmount);

                    emit LogDistributed(_staking, reward, rewardAmount);
                }
            }
        }
    }
}
