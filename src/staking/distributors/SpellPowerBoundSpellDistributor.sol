// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {MultiRewards} from "/staking/MultiRewards.sol";

/// @notice Receives BoundSPELL from BoundSpellTokenLocker and distributes to MultiRewards
contract SpellPowerBoundSpellDistributor is OwnableOperators {
    using SafeTransferLib for address;

    event LogRescue(address token, uint256 amount);

    MultiRewards public immutable staking;
    address public immutable bSpell;

    constructor(MultiRewards staking_, address bSpell_, address _owner) {
        staking = staking_;
        bSpell = bSpell_;

        bSpell.safeApprove(address(staking), type(uint256).max);
        _initializeOwner(_owner);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// Operators
    //////////////////////////////////////////////////////////////////////////////////////////////

    function distribute(uint256 amount) external onlyOperators {
        MultiRewards(staking).notifyRewardAmount(bSpell, amount);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// Owner
    //////////////////////////////////////////////////////////////////////////////////////////////

    function rescue(address token, uint256 amount) external onlyOwner {
        token.safeTransfer(msg.sender, amount);
        emit LogRescue(token, amount);
    }
}
