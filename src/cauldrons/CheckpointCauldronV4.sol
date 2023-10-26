// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "BoringSolidity/libraries/BoringRebase.sol";
import "cauldrons/CauldronV4.sol";
import "libraries/compat/BoringMath.sol";
import "interfaces/ICheckpointToken.sol";
import "interfaces/IWhitelister.sol";

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

/// @notice Cauldron with both whitelisting and checkpointing token rewards on add/remove/liquidate collateral
contract WhitelistedCheckpointCauldronV4 is CheckpointCauldronV4 {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using RebaseLibrary for Rebase;

    error ErrWhitelistedBorrowExceeded();
    event LogChangeWhitelister(IWhitelister indexed newWhiteLister);

    uint8 public constant ACTION_SET_MAX_BORROW = ACTION_CUSTOM_START_INDEX + 1;

    IWhitelister public whitelister;

    constructor(IBentoBoxV1 box, IERC20 mim) CheckpointCauldronV4(box, mim) {}

    function _preBorrowAction(address, uint256, uint256 newBorrowPart, uint256) internal view override {
        if (whitelister != IWhitelister(address(0)) && !whitelister.isBorrowingAllowed(msg.sender, newBorrowPart)) {
            revert ErrWhitelistedBorrowExceeded();
        }
    }

    function _additionalCookAction(
        uint8 action,
        CookStatus memory status,
        uint256,
        bytes memory data,
        uint256,
        uint256
    ) internal virtual override returns (bytes memory, uint8, CookStatus memory) {
        if (action == ACTION_SET_MAX_BORROW) {
            (address user, uint256 maxBorrow, bytes32[] memory merkleProof) = abi.decode(data, (address, uint256, bytes32[]));
            whitelister.setMaxBorrow(user, maxBorrow, merkleProof);
        }

        return ("", 0, status);
    }

    function changeWhitelister(IWhitelister newWhiteLister) public onlyMasterContractOwner {
        whitelister = newWhiteLister;
        emit LogChangeWhitelister(newWhiteLister);
    }
}
