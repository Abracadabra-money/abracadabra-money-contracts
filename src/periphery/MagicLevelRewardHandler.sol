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
    IERC20 public rewardToken;
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
    /// @dev Avoid adding storage variable in this contract.
    /// Use MagicLevelData instead.
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice harvests rewards from the staking contract and distributes them to the vault
    /// @param to Address to send the rewards to
    function harvest(address to) external override onlyOperators {
        staking.harvest(pid, to);
        rewardToken.safeTransfer(to, rewardToken.balanceOf(address(this)));
    }

    /// @notice distributes rewards to the staking contract
    /// @param amount Amount of rewards to distribute
    function distributeRewards(uint256 amount) external override onlyOperators {
        _asset.transferFrom(msg.sender, address(this), amount);
        staking.deposit(pid, amount, address(this));
        _totalAssets += amount;
    }

    /// @notice Skims excess assets from the staking contract and current contract balance
    function skimAssets() external override onlyOwner returns (uint256 excessStakedAmount, uint256 excessLpAmount) {
        (uint256 stakedAmount, ) = staking.userInfo(pid, address(this));
        excessStakedAmount = stakedAmount - _totalAssets;
        staking.withdraw(pid, excessStakedAmount, msg.sender);

        excessLpAmount = _asset.balanceOf(address(this));

        if (excessLpAmount > 0) {
            _asset.transfer(msg.sender, excessLpAmount);
        }
    }

    /// @notice Sets the staking contract and pid and approves the staking contract to spend the asset
    /// @param _staking Staking contract
    /// @param _pid Pool id
    function setStakingInfo(ILevelFinanceStaking _staking, uint96 _pid) external override onlyOwner {
        emit LogStakingInfoChanged(staking, pid, _staking, _pid);
        staking = _staking;
        pid = _pid;
        rewardToken = IERC20(_staking.rewardToken());
        _asset.approve(address(_staking), type(uint256).max);
    }

    /// @notice Returns the staking contract and pid
    function stakingInfo() external view override returns (ILevelFinanceStaking, uint96) {
        return (staking, pid);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Private Delegate Functions
    // Only allowed to be called by the MagicLevel contract
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Stakes the asset in the staking contract
    function stakeAsset(uint256 amount) external override {
        staking.deposit(pid, amount, address(this));
    }

    /// @notice Unstakes the asset in the staking contract
    function unstakeAsset(uint256 amount) external override {
        staking.withdraw(pid, amount, address(this));
    }

    /// @notice Private functions are not meant to be called by the fallback function directly
    /// as they would compromise the state of the contract.
    function isPrivateDelegateFunction(bytes4 sig) external pure returns (bool) {
        return sig == this.stakeAsset.selector || sig == this.unstakeAsset.selector;
    }
}
