// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {ICauldronV2} from "interfaces/ICauldronV2.sol";
import {IOracle} from "interfaces/IOracle.sol";

library CauldronTestLib {
    function depositAndBorrow(
        IBentoBoxV1 box,
        ICauldronV2 cauldron,
        address masterContract,
        IERC20 collateral,
        address account,
        uint256 amount,
        uint8 percentBorrow
    ) internal returns (uint256 borrowAmount) {
        box.setMasterContractApproval(account, masterContract, true, 0, 0, 0);

        collateral.approve(address(box), amount);
        (, borrowAmount) = box.deposit(collateral, account, account, amount, 0);
        cauldron.addCollateral(account, false, borrowAmount);

        amount = (1e18 * amount) / cauldron.oracle().peekSpot("");
        borrowAmount = (amount * percentBorrow) / 100;
        cauldron.borrow(account, borrowAmount);

        box.withdraw(cauldron.magicInternetMoney(), account, account, borrowAmount, 0);
    }
}
