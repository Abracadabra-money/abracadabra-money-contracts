// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {CauldronV4} from "cauldrons/CauldronV4.sol";
import {RebaseLibrary, Rebase} from "BoringSolidity/libraries/BoringRebase.sol";

contract PrivilegedCauldronV4 is CauldronV4 {
    using RebaseLibrary for Rebase;

    constructor(IBentoBoxV1 bentoBox_, IERC20 magicInternetMoney_) CauldronV4(bentoBox_, magicInternetMoney_) {}

    /// @dev masterContract Owner should call updateExchangeRate() before single or multiple call to this function
    function addBorrowPosition(address to, uint256 amount) external onlyMasterContractOwner returns (uint256 part) {
        (totalBorrow, part) = totalBorrow.add(amount, true);

        userBorrowPart[to] = userBorrowPart[to] + part;

        emit LogBorrow(msg.sender, to, amount, part);

        require(_isSolvent(to, exchangeRate), "Cauldron: user insolvent");
    }
}
