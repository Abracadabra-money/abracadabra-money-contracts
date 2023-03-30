// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/libraries/BoringERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import {MagicLevelData} from "tokens/MagicLevel.sol";
import "interfaces/ILevelFinanceStaking.sol";
import "interfaces/IMagicLevelRewardHandler.sol";

/// @dev in case of V2, if adding new variable create MagicLevelRewardHandlerDataV2 that inherits
/// from MagicLevelRewardHandlerDataV1
contract MagicLevelRewardHandlerDataV1 is MagicLevelData {
    ILevelFinanceStaking staking;
    uint96 pid;
    IERC20 rewardToken;
}

/// @dev When making a new version, never change existing variables, always add after
/// the existing one. Ex: Inherit from MagicLevelRewardHandlerDataV2 in case of a V2 version.
contract MagicLevelRewardHandler is MagicLevelRewardHandlerDataV1, IMagicLevelRewardHandler {
    using BoringERC20 for IERC20;

    event LogStakingInfoChanged(
        ILevelFinanceStaking indexed previousStaking,
        uint96 previousPid,
        ILevelFinanceStaking indexed currentStaking,
        uint96 indexed currentPid
    );

    ////////////////////////////////////////////////////////////////////////////////
    /// @dev Avoid adding storage variable here
    /// Should use MagicLevelData instead.
    ////////////////////////////////////////////////////////////////////////////////

    function harvest(address to) external override onlyStrategyExecutor {
        staking.harvest(pid, to);
        rewardToken.safeTransfer(to, rewardToken.balanceOf(address(this)));
    }

    function distributeRewards(uint256 amount) external override onlyStrategyExecutor {
        _asset.transferFrom(msg.sender, address(this), amount);
        staking.deposit(pid, amount, address(this));
        _totalAssets += amount;
    }

    function deposit(uint256 amount) external override onlyVault {
        staking.deposit(pid, amount, address(this));
    }

    function withdraw(uint256 amount) external override onlyVault {
        staking.withdraw(pid, amount, address(this));
    }

    function skimAssets() external override onlyOwner returns (uint256 amount) {
        amount = _asset.balanceOf(address(this)) - _totalAssets;

        if (amount > 0) {
            _asset.transfer(msg.sender, amount);
        }
    }

    function setStakingInfo(ILevelFinanceStaking _staking, uint96 _pid) external override onlyOwner {
        emit LogStakingInfoChanged(staking, pid, _staking, _pid);
        staking = _staking;
        pid = _pid;

        rewardToken = IERC20(staking.rewardToken());
    }

    function stakingInfo() external pure override returns (ILevelFinanceStaking staking, uint96 pid) {
        return (staking, pid);
    }
}
