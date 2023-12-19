// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "BoringSolidity/ERC20.sol";
import {RebaseLibrary, Rebase} from "BoringSolidity/libraries/BoringRebase.sol";
import {BoringERC20, IERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {Operatable} from "mixins/Operatable.sol";
import {ICauldronV4} from "interfaces/ICauldronV4.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";

contract RepayHelper {
    using RebaseLibrary for Rebase;
    using BoringERC20 for IERC20;

    IERC20 public immutable magicInternetMoney;
    address public constant multisig = 0x5f0DeE98360d8200b20812e174d139A1a633EDd2;
    address public constant safe = 0xDF2C270f610Dc35d8fFDA5B453E74db5471E126B;

    error ErrNotAllowed();

    event LogTotalRepaid(ICauldronV4 indexed cauldron, uint256 amount);

    modifier onlySafe() {
        if (msg.sender != safe) {
            revert ErrNotAllowed();
        }
        _;
    }

    modifier onlyMultisig() {
        if (msg.sender != multisig) {
            revert ErrNotAllowed();
        }
        _;
    }

    constructor(IERC20 magicInternetMoney_) {
        magicInternetMoney = magicInternetMoney_;
    }

    /// @notice Repays a loan.
    /// @param to Address of the user this payment should go.
    /// @param cauldron cauldron on which it is repaid
    /// @param amount The amount to repay.
    /// @return part The total part repayed.
    function repayAmount(address to, ICauldronV4 cauldron, uint256 amount) public onlySafe returns (uint256 part) {
        cauldron.accrue();
        Rebase memory totalBorrow = cauldron.totalBorrow();
        part = totalBorrow.toBase(amount - 1, true);

        cauldron.repay(to, true, part);
    }

    /// @notice Repays multiple loans completely
    /// @param to Address of the users this payment should go.
    /// @param cauldron cauldron on which it is repaid
    function repayTotal(address[] calldata to, ICauldronV4 cauldron) external onlySafe returns (uint256 amount) {
        cauldron.accrue();
        Rebase memory totalBorrow = cauldron.totalBorrow();

        uint totalPart;
        for (uint i; i < to.length; i++) {
            totalPart += cauldron.userBorrowPart(to[i]);
        }

        amount = totalBorrow.toElastic(totalPart + 1e6, true);
        IBentoBoxV1 bentoBox = IBentoBoxV1(address(cauldron.bentoBox()));

        magicInternetMoney.safeTransferFrom(safe, address(bentoBox), amount);
        bentoBox.deposit(magicInternetMoney, address(bentoBox), address(bentoBox), amount, 0);

        for (uint i; i < to.length; i++) {
            cauldron.repay(to[i], true, cauldron.userBorrowPart(to[i]));
        }

        emit LogTotalRepaid(cauldron, amount);
    }

    /// @notice Repays multiple loans completely
    /// @param to Address of the users this payment should go.
    /// @param cauldron cauldron on which it is repaid
    function repayTotalMultisig(address[] calldata to, ICauldronV4 cauldron) external onlyMultisig returns (uint256 amount) {
        cauldron.accrue();
        Rebase memory totalBorrow = cauldron.totalBorrow();

        uint totalPart;
        for (uint i; i < to.length; i++) {
            totalPart += cauldron.userBorrowPart(to[i]);
        }

        amount = totalBorrow.toElastic(totalPart + 1e6, true);
        IBentoBoxV1 bentoBox = IBentoBoxV1(address(cauldron.bentoBox()));

        magicInternetMoney.safeTransferFrom(multisig, address(bentoBox), amount);
        bentoBox.deposit(magicInternetMoney, address(bentoBox), address(bentoBox), amount, 0);

        for (uint i; i < to.length; i++) {
            cauldron.repay(to[i], true, cauldron.userBorrowPart(to[i]));
        }

        emit LogTotalRepaid(cauldron, amount);
    }
}
