// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import {IBentoBoxV1} from "/interfaces/IBentoBoxV1.sol";
import {ICauldronV2} from "/interfaces/ICauldronV2.sol";
import {IOracle} from "/interfaces/IOracle.sol";
import {Toolkit} from "utils/Toolkit.sol";
import {ExchangeRouterMock} from "../mocks/ExchangeRouterMock.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";

library CauldronTestLib {
    Toolkit constant toolkit = Toolkit(address(bytes20(uint160(uint256(keccak256("toolkit"))))));

    function depositAndBorrow(
        IBentoBoxV1 box,
        ICauldronV2 cauldron,
        address masterContract,
        IERC20 collateral,
        address account,
        uint256 amount,
        uint8 percentBorrow
    ) internal returns (uint256 borrowAmount) {
        return depositAndBorrowTo(box, cauldron, masterContract, collateral, account, amount, percentBorrow, account);
    }

    function depositAndBorrowTo(
        IBentoBoxV1 box,
        ICauldronV2 cauldron,
        address masterContract,
        IERC20 collateral,
        address account,
        uint256 amount,
        uint8 percentBorrow,
        address to
    ) internal returns (uint256 borrowAmount) {
        box.setMasterContractApproval(account, masterContract, true, 0, 0, 0);

        collateral.approve(address(box), amount);
        (, borrowAmount) = box.deposit(collateral, account, account, amount, 0);
        cauldron.addCollateral(account, false, borrowAmount);
        address mim = address(cauldron.magicInternetMoney());

        amount = (1e18 * amount) / cauldron.oracle().peekSpot(cauldron.oracleData());
        borrowAmount = (amount * percentBorrow) / 100;

        uint256 mlb = box.toAmount(IERC20(mim), box.balanceOf(IERC20(mim), address(cauldron)), false);

        if (borrowAmount > mlb) {
            revert(
                string.concat(
                    "CauldronTestLib: Not enough MIM to borrow. Trying to borrow ",
                    toolkit.formatDecimals(borrowAmount),
                    " MIM but MLB is ",
                    toolkit.formatDecimals(mlb),
                    " MIM."
                )
            );
        }

        cauldron.borrow(account, borrowAmount);

        uint256 mimAmount = box.toAmount(IERC20(mim), box.balanceOf(IERC20(mim), address(account)), false);
        if (borrowAmount > mimAmount) {
            borrowAmount = mimAmount;
        }

        require(borrowAmount > 0, "CauldronTestLib: Borrow amount is zero");

        box.withdraw(cauldron.magicInternetMoney(), account, to, borrowAmount, 0);
    }
}
