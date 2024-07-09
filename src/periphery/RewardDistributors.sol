// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {OperatableV2} from "mixins/OperatableV2.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IEpochBasedStaking} from "interfaces/IEpochBasedStaking.sol";
import {IMultiRewardsStaking} from "interfaces/IMultiRewardsStaking.sol";

abstract contract BaseRewardDistributor is OperatableV2 {
    using SafeTransferLib for address;

    event LogRescue(address indexed token, address indexed to, uint256 amount);
    event LogRewardDistributionSet(address indexed staking, address indexed reward, uint256 amount);
    event LogVaultSet(address indexed previous, address indexed current);
    event LogDistributed(address indexed staking, address indexed reward, uint256 amount);

    error ErrNotReady();

    bytes public constant MSG_NO_REWARDS_TO_DISTRIBUTE = bytes("No reward tokens to distribute");
    bytes public constant MSG_NOT_READY = bytes("Reward distributor not ready");

    mapping(address staking => mapping(address token => uint256 amount)) public rewardDistributions;

    address public vault;

    constructor(address _vault, address _owner) OperatableV2(_owner) {
        vault = _vault;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function distribute(address _staking) external onlyOperators {
        if (!ready(_staking)) {
            revert ErrNotReady();
        }

        _onDistribute(_staking);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function checker(address _staking) external view returns (bool canExec, bytes memory execPayload) {
        if (!ready(_staking)) {
            return (false, MSG_NOT_READY);
        }

        bytes memory payload = _onChecker(_staking);

        if (payload.length > 0) {
            return (true, payload);
        }

        return (false, MSG_NO_REWARDS_TO_DISTRIBUTE);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /// TO IMPLEMENT
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function ready(address _staking) public view virtual returns (bool);

    function _onChecker(address _staking) internal view virtual returns (bytes memory);

    function _onDistribute(address _staking) internal virtual;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function setRewardDistribution(address _staking, address _token, uint256 _amount) external onlyOwner {
        rewardDistributions[_staking][_token] = _amount;

        if (_amount > 0) {
            _token.safeApprove(_staking, type(uint256).max);
        }

        emit LogRewardDistributionSet(_staking, _token, _amount);
    }

    function setVault(address _vault) external onlyOwner {
        emit LogVaultSet(vault, _vault);
        vault = _vault;
    }

    function setAllowance(address _token, address _spender, uint256 _amount) external onlyOwner {
        _token.safeApprove(_spender, _amount);
    }

    function rescue(address _token, address _to, uint256 _amount) external onlyOwner {
        _token.safeTransfer(_to, _amount);
        emit LogRescue(_token, _to, _amount);
    }
}

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
        return lastDistributedEpoch[_staking] < IEpochBasedStaking(_staking).epoch();
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
                IEpochBasedStaking(_staking).notifyRewardAmount(reward, rewardAmount, type(uint256).max);

                emit LogDistributed(_staking, reward, rewardAmount);
            }
        }

        lastDistributedEpoch[_staking] = IEpochBasedStaking(_staking).nextEpoch();
    }

    function _onChecker(address _staking) internal view override returns (bytes memory) {
        uint256 rewardLength = IEpochBasedStaking(_staking).rewardTokensLength();

        for (uint256 i = 0; i < rewardLength; i++) {
            if (rewardDistributions[_staking][IEpochBasedStaking(_staking).rewardTokens(i)] > 0) {
                return abi.encodeCall(BaseRewardDistributor.distribute, _staking);
            }
        }

        return "";
    }
}

contract MultiRewardsDistributor is BaseRewardDistributor {
    using SafeTransferLib for address;

    event LogDistributed();

    constructor(address _vault, address _owner) BaseRewardDistributor(_vault, _owner) {}

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function ready(address _staking) public view override returns (bool) {
        uint256 rewardLength = IMultiRewardsStaking(_staking).getRewardTokenLength();

        for (uint256 i = 0; i < rewardLength; i++) {
            uint256 periodFinish = IMultiRewardsStaking(_staking).rewardData(IMultiRewardsStaking(_staking).rewardTokens(i)).periodFinish;
            if (block.timestamp >= periodFinish) {
                return true;
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

    function _onChecker(address _staking) internal view override returns (bytes memory) {
        uint256 rewardLength = IMultiRewardsStaking(_staking).getRewardTokenLength();

        for (uint256 i = 0; i < rewardLength; i++) {
            if (rewardDistributions[_staking][IMultiRewardsStaking(_staking).rewardTokens(i)] > 0) {
                return abi.encodeCall(BaseRewardDistributor.distribute, _staking);
            }
        }

        return "";
    }
}
