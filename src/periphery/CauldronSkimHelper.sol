// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ICauldronV2} from "/interfaces/ICauldronV2.sol";

contract CauldronSkimHelper {
    /// @notice Get the available skim amount for the caller cauldron.
    /// Designed for use as a call action in `cook`. Typically followed
    /// by an add collateral action that skims available amount of shares.
    function availableSkim() public view returns (uint256 share) {
        // Assume caller is a cauldron
        ICauldronV2 cauldron = ICauldronV2(msg.sender);
        return IBentoBoxLite(cauldron.bentoBox()).balanceOf(address(cauldron.collateral()), msg.sender) - cauldron.totalCollateralShare();
    }
}
