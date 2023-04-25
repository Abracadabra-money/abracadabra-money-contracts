// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "BoringSolidity/libraries/BoringRebase.sol";
import "cauldrons/CauldronV4.sol";
import "libraries/compat/BoringMath.sol";
import "interfaces/ICheckpointToken.sol";

/// @notice Cauldron with checkpointing token rewards on add/remove/liquidate collateral
/// @dev `user_checkpoint` checkpoint must always be called before userCollateralShare is changed
contract CheckpointCauldronV4 is CauldronV4 {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using RebaseLibrary for Rebase;

    constructor(IBentoBoxV1 box, IERC20 mim) CauldronV4(box, mim) {}

    function addCollateral(address to, bool skim, uint256 share) public override {
        ICheckpointToken(address(collateral)).user_checkpoint(to);
        super.addCollateral(to, skim, share);
    }

    function _removeCollateral(address to, uint256 share) internal override {
        ICheckpointToken(address(collateral)).user_checkpoint(address(msg.sender));
        super._removeCollateral(to, share);
    }

    function _beforeUserLiquidated(
        address user,
        uint256 /* borrowPart */,
        uint256 /* borrowAmount */,
        uint256 /* collateralShare */
    ) internal override {
        ICheckpointToken(address(collateral)).user_checkpoint(user);
    }
}
