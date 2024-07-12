// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IEpochBasedStaking} from "interfaces/IEpochBasedStaking.sol";
import {BaseRewardDistributor} from "staking/distributors/BaseRewardDistributor.sol";

/// @notice Distribute rewards to staking contracts based on epochs
/// Amounts deposited to this contract are distributed to staking contracts
/// only on the next epoch
contract EpochBasedRewardDistributor is BaseRewardDistributor {
    using SafeTransferLib for address;

    event LogMaxDistributionTimeWindowSet(uint256 oldMaxDistributionTimeWindow, uint256 newMaxDistributionTimeWindow);

    mapping(address staking => uint256 epoch) public lastDistributedEpoch;

    constructor(address _vault, address _owner) BaseRewardDistributor(_vault, _owner) {}

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function ready(address _staking) public view override returns (bool) {
        uint256 rewardLength = IEpochBasedStaking(_staking).rewardTokensLength();

        for (uint256 i = 0; i < rewardLength; i++) {
            address reward = IEpochBasedStaking(_staking).rewardTokens(i);
            uint256 rewardAmount = rewardDistributions[_staking][reward];

            if (rewardAmount > 0) {
                if (block.timestamp >= IEpochBasedStaking(_staking).rewardData(reward).periodFinish) {
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
        uint256 rewardLength = IEpochBasedStaking(_staking).rewardTokensLength();

        for (uint256 i = 0; i < rewardLength; i++) {
            address reward = IEpochBasedStaking(_staking).rewardTokens(i);
            uint256 rewardAmount = rewardDistributions[_staking][reward];

            if (rewardAmount > 0) {
                reward.safeTransferFrom(vault, address(this), rewardAmount);
                IEpochBasedStaking(_staking).notifyRewardAmount(reward, rewardAmount, 0);

                emit LogDistributed(_staking, reward, rewardAmount);
            }
        }

        lastDistributedEpoch[_staking] = IEpochBasedStaking(_staking).nextEpoch();
    }
}
