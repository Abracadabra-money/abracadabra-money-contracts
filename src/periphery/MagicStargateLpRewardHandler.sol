// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/libraries/BoringERC20.sol";
import {MagicStargateLpData} from "tokens/MagicStargateLp.sol";
import {IMagicStargateLpRewardHandler} from "interfaces/IMagicStargateLpRewardHandler.sol";

/// @dev in case of V2, if adding new variable create MagicStargateLpRewardHandlerDataV2 that inherits
/// from MagicStargateLpRewardHandlerDataV1
contract MagicStargateLpRewardHandlerDataV1 is MagicStargateLpData {
    ICurveRewardGauge _staking;
}

/// @dev When making a new version, never change existing variables, always add after
/// the existing one. Ex: Inherit from MagicStargateLpRewardHandlerDataV2 in case of a V2 version.
contract MagicStargateLpRewardHandler is MagicStargateLpRewardHandlerDataV1, IMagicStargateLpRewardHandler {
    using BoringERC20 for IERC20;

    event LogStakingChanged(ICurveRewardGauge indexed previousStaking, ICurveRewardGauge indexed currentStaking);

    ////////////////////////////////////////////////////////////////////////////////
    /// @dev Avoid adding storage variable in this contract.
    /// Use MagicStargateLpRewardHandlerData instead.
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice harvests rewards from the staking contract and distributes them to the vault
    /// @param to Address to send the rewards to
    function harvest(address to) external override onlyOperators {
        _staking.claim_rewards(address(this), to);
    }

    /// @notice distributes rewards to the staking contract
    /// @param amount Amount of rewards to distribute
    function distributeRewards(uint256 amount) external override onlyOperators {
        _asset.transferFrom(msg.sender, address(this), amount);
        _staking.deposit(amount, address(this), false);
        _totalAssets += amount;
    }

    /// @notice Skims excess assets from the staking contract and current contract balance
    function skimAssets() external override onlyOwner returns (uint256 excessStakedAmount, uint256 excessLpAmount) {
        uint256 stakedAmount = _staking.balanceOf(address(this));

        excessStakedAmount = stakedAmount - _totalAssets;
        excessLpAmount = _asset.balanceOf(address(this));

        _staking.withdraw(excessStakedAmount);

        uint total = _asset.balanceOf(address(this));

        if (total > 0) {
            _asset.transfer(msg.sender, total);
        }
    }

    /// @notice Sets the staking contract and pid and approves the staking contract to spend the asset
    /// @param __staking Staking contract
    function setStaking(ICurveRewardGauge __staking) external override onlyOwner {
        emit LogStakingChanged(_staking, __staking);
        _staking = __staking;
        _asset.approve(address(__staking), type(uint256).max);
    }

    /// @notice Returns the staking contract and pid
    function staking() external view override returns (ICurveRewardGauge) {
        return _staking;
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Private Delegate Functions
    // Only allowed to be called by the MagicStargateLp contract
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Stakes the asset in the staking contract
    function stakeAsset(uint256 amount) external override {
        _staking.deposit(amount, address(this), false);
    }

    /// @notice Unstakes the asset in the staking contract
    function unstakeAsset(uint256 amount) external override {
        _staking.withdraw(amount);
    }

    /// @notice Private functions are not meant to be called by the fallback function directly
    /// as they would compromise the state of the contract.
    function isPrivateDelegateFunction(bytes4 sig) external pure returns (bool) {
        return sig == this.stakeAsset.selector || sig == this.unstakeAsset.selector;
    }
}
