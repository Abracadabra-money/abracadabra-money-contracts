// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/ERC20.sol";
import "BoringSolidity/libraries/BoringRebase.sol";
import "periphery/Operatable.sol";
import "interfaces/ICauldronV4.sol";
import "interfaces/IBentoBoxV1.sol";

contract DegenBoxHelper is Operatable {
    using RebaseLibrary for Rebase;

    IBentoBoxV1 immutable public degenBox;
    IERC20 immutable public magicInternetMoney;

    constructor (IBentoBoxV1 degenBox_, IERC20 magicInternetMoney_) {
        degenBox = degenBox_;
        magicInternetMoney = magicInternetMoney_;
        degenBox_.registerProtocol();
    }

    function degenBoxDeposit(IERC20 token, address to, uint256 amount, uint256 share ) external payable onlyOperators returns (uint256, uint256) {
        return degenBox.deposit{value: msg.value}(token, tx.origin, to, uint256(amount), uint256(share));
    }

    function degenBoxWithdraw(IERC20 token, address to, uint256 amount, uint256 share) external onlyOperators returns (uint256, uint256) {
        return degenBox.withdraw(token, tx.origin, to, amount, share);
    }

    /// @notice Repays a loan.
    /// @param to Address of the user this payment should go.
    /// @param cauldron cauldron on which it is repaid
    /// @param part The amount to repay. See `userBorrowPart`.
    /// @return amount The total amount repayed.
    function repayPart(
        address to,
        ICauldronV4 cauldron,
        uint256 part
    ) public onlyOperators returns (uint256 amount) {
        Rebase memory totalBorrow = cauldron.totalBorrow();
        amount = totalBorrow.toElastic(part, true);

        uint256 share = degenBox.toShare(magicInternetMoney, amount, true);
        degenBox.transfer(magicInternetMoney, tx.origin, address(cauldron), share);
        cauldron.repay(to, true, part);
    }

}
