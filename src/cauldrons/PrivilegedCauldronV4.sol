// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;
import "cauldrons/CauldronV4.sol";
import "BoringSolidity/libraries/BoringRebase.sol";

contract PrivilegedCauldronV4 is CauldronV4 {
    using RebaseLibrary for Rebase;
    constructor (IBentoBoxV1 bentoBox_, IERC20 magicInternetMoney_) CauldronV4 (bentoBox_, magicInternetMoney_) {

    }
    function addBorrowPosition(address to, uint256 amount) external onlyMasterContractOwner returns (uint256 part) {
        (totalBorrow, part) = totalBorrow.add(amount, true);
        
        userBorrowPart[to] = userBorrowPart[to] + part;

        emit LogBorrow(msg.sender, to, amount, part);

        (, uint256 _exchangeRate) = updateExchangeRate();
        require(_isSolvent(to, _exchangeRate), "Cauldron: user insolvent");
    }

}