// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ICauldronV4.sol";

contract CauldronPositionsLens {
    struct UserPosition {
        uint256 borrowPart;
        uint256 collateralShare;
    }

    function getPositions(
        IBentoBoxV1 bentoBox,
        IERC20 collateral,
        ICauldronV4 cauldron,
        bytes calldata oracleData,
        address[] calldata accounts
    )
        public
        view
        returns (
            Rebase memory totalToken,
            Rebase memory totalBorrow,
            uint256 exchangeRate,
            UserPosition[] memory positions
        )
    {
        // On-fly accrue interests
        totalBorrow = cauldron.totalBorrow();
        (uint64 lastAccrued, , uint64 INTEREST_PER_SECOND) = cauldron.accrueInfo();
        uint256 elapsedTime = block.timestamp - lastAccrued;

        if (elapsedTime != 0 && totalBorrow.base != 0) {
            totalBorrow.elastic = totalBorrow.elastic + uint128((uint256(totalBorrow.elastic) * INTEREST_PER_SECOND * elapsedTime) / 1e18);
        }

        positions = new UserPosition[](accounts.length);

        totalToken = bentoBox.totals(collateral);
        exchangeRate = cauldron.oracle().peekSpot(oracleData);

        for (uint256 i = 0; i < accounts.length; i++) {
            positions[i].borrowPart = cauldron.userBorrowPart(accounts[i]);
            positions[i].collateralShare = cauldron.userCollateralShare(accounts[i]);
        }
    }
}
