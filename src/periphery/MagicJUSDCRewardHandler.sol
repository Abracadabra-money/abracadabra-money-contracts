// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20, BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {MagicJUSDC, MagicJUSDCData} from "tokens/MagicJUSDC.sol";
import {IMagicCurveLpRewardHandler} from "interfaces/IMagicCurveLpRewardHandler.sol";
import {IMiniChefV2} from "interfaces/IMiniChefV2.sol";
import {IMagicJUSDCRewardHandler} from "interfaces/IMagicJUSDCRewardHandler.sol";

/// @dev in case of V2, if adding new variable create MagicJUSDCRewardHandlerDataV2 that inherits
/// from MagicJUSDCRewardHandlerDataV1
contract MagicJUSDCRewardHandlerDataV1 is MagicJUSDCData {
    IMiniChefV2 _staking;
}

/// @dev When making a new version, never change existing variables, always add after
/// the existing one. Ex: Inherit from MagicJUSDCRewardHandlerDataV2 in case of a V2 version.
contract MagicJUSDCRewardHandler is MagicJUSDCRewardHandlerDataV1, IMagicJUSDCRewardHandler {
    using BoringERC20 for IERC20;

    uint96 public constant PID = 0;

    event LogStakingChanged(IMiniChefV2 indexed previousStaking, IMiniChefV2 indexed currentStaking);

    ////////////////////////////////////////////////////////////////////////////////
    /// @dev Avoid adding storage variable in this contract.
    /// Use MagicJUSDCRewardHandlerData instead.
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice harvests rewards from the staking contract and distributes them to the vault
    /// @param to Address to send the rewards to
    function harvest(address to) external override onlyOperators {
        _staking.withdraw(PID, 0, to);
    }

    /// @notice distributes rewards to the staking contract
    /// @param amount Amount of rewards to distribute
    function distributeRewards(uint256 amount) external override onlyOperators {
        _asset.transferFrom(msg.sender, address(this), amount);
        _staking.deposit(PID, amount, address(this));
        _totalAssets += amount;
    }

    /// @notice Skims excess assets from the staking contract and current contract balance
    function skimAssets() external override onlyOwner returns (uint256 excessStakedAmount, uint256 excessAmount) {
        (uint256 stakedAmount, ) = _staking.userInfo(PID, address(this));

        excessStakedAmount = stakedAmount - _totalAssets;
        excessAmount = _asset.balanceOf(address(this));

        _staking.withdraw(PID, excessStakedAmount, address(this));

        uint total = excessAmount + excessStakedAmount;

        if (total > 0) {
            _asset.transfer(msg.sender, total);
        }
    }

    /// @notice Sets the staking contract and pid and approves the staking contract to spend the asset
    /// @param __staking Staking contract
    function setStaking(IMiniChefV2 __staking) external override onlyOwner {
        emit LogStakingChanged(_staking, __staking);
        _staking = __staking;
        _asset.approve(address(__staking), type(uint256).max);
    }

    /// @notice Returns the staking contract and pid
    function stakingInfo() external view override returns (IMiniChefV2, uint96) {
        return (_staking, PID);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Private Delegate Functions
    // Only allowed to be called by the MagicCurveLp contract
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Stakes the asset in the staking contract
    function stakeAsset(uint256 amount) external override {
        _staking.deposit(PID, amount, address(this));
    }

    /// @notice Unstakes the asset in the staking contract
    function unstakeAsset(uint256 amount) external override {
        _staking.withdraw(PID, amount, address(this));
    }

    /// @notice Private functions are not meant to be called by the fallback function directly
    /// as they would compromise the state of the contract.
    function isPrivateDelegateFunction(bytes4 sig) external pure returns (bool) {
        return sig == this.stakeAsset.selector || sig == this.unstakeAsset.selector;
    }
}
