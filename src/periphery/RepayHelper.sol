// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/ERC20.sol";
import "BoringSolidity/libraries/BoringRebase.sol";
import "periphery/Operatable.sol";
import "interfaces/ICauldronV4.sol";
import "interfaces/IBentoBoxV1.sol";

contract RepayHelper {
    using RebaseLibrary for Rebase;

    IERC20 immutable public magicInternetMoney;

    constructor (IERC20 magicInternetMoney_) {
        magicInternetMoney = magicInternetMoney_;
    }

    /// @notice Repays a loan.
    /// @param to Address of the user this payment should go.
    /// @param cauldron cauldron on which it is repaid
    /// @param amount The amount to repay.
    /// @return part The total part repayed.
    function repayAmount(
        address to,
        ICauldronV4 cauldron,
        uint256 amount
    ) public returns (uint256 part) {
        cauldron.accrue();
        Rebase memory totalBorrow = cauldron.totalBorrow();
        part = totalBorrow.toBase(amount - 1, true);

        cauldron.repay(to, true, part);
    }

}
