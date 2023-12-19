// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {CauldronV4} from "cauldrons/CauldronV4.sol";
import {IWhitelister} from "interfaces/IWhitelister.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {RebaseLibrary, Rebase} from "BoringSolidity/libraries/BoringRebase.sol";

contract WhitelistedCauldronV4 is CauldronV4 {
    using RebaseLibrary for Rebase;

    error ErrWhitelistedBorrowExceeded();

    uint8 public constant ACTION_SET_MAX_BORROW = ACTION_CUSTOM_START_INDEX + 1;

    IWhitelister public whitelister;

    constructor(IBentoBoxV1 bentoBox_, IERC20 magicInternetMoney_) CauldronV4(bentoBox_, magicInternetMoney_) {}

    event LogChangeWhitelister(IWhitelister indexed newWhiteLister);

    function _preBorrowAction(address, uint256, uint256 newBorrowPart, uint256) internal view override {
        if (whitelister != IWhitelister(address(0)) && !whitelister.isBorrowingAllowed(msg.sender, newBorrowPart)) {
            revert ErrWhitelistedBorrowExceeded();
        }
    }

    function _additionalCookAction(
        uint8 action,
        CookStatus memory status,
        uint256 /*value*/,
        bytes memory data,
        uint256 /*value1*/,
        uint256 /*value2*/
    ) internal virtual override returns (bytes memory /*returnData*/, uint8 /*returnValues*/, CookStatus memory /*updatedStatus*/) {
        if (action == ACTION_SET_MAX_BORROW) {
            (address user, uint256 maxBorrow, bytes32[] memory merkleProof) = abi.decode(data, (address, uint256, bytes32[]));
            whitelister.setMaxBorrow(user, maxBorrow, merkleProof);
        }

        return ("", 0, status);
    }

    /// @notice allows to change the whitelister
    /// @param newWhiteLister new whitelisting address
    function changeWhitelister(IWhitelister newWhiteLister) public onlyMasterContractOwner {
        whitelister = newWhiteLister;
        emit LogChangeWhitelister(newWhiteLister);
    }
}
