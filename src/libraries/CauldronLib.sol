// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {RebaseLibrary, Rebase} from "BoringSolidity/libraries/BoringRebase.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {ICauldronV2} from "interfaces/ICauldronV2.sol";
import {ICauldronV3} from "interfaces/ICauldronV3.sol";
import {ICauldronV4} from "interfaces/ICauldronV4.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {MathLib} from "libraries/MathLib.sol";

library CauldronLib {
    using BoringERC20 for IERC20;
    using RebaseLibrary for Rebase;

    uint256 internal constant EXCHANGE_RATE_PRECISION = 1e18;
    uint256 internal constant BPS_PRECISION = 1e4;
    uint256 internal constant COLLATERIZATION_RATE_PRECISION = 1e5;
    uint256 internal constant LIQUIDATION_MULTIPLIER_PRECISION = 1e5;
    uint256 internal constant DISTRIBUTION_PART = 10;
    uint256 internal constant DISTRIBUTION_PRECISION = 100;

    /// @dev example: 200 is 2% interests
    function getInterestPerSecond(uint256 interestBips) internal pure returns (uint64 interestsPerSecond) {
        return uint64((interestBips * 316880878) / 100); // 316880878 is the precomputed integral part of 1e18 / (36525 * 3600 * 24)
    }

    function getInterestPerYearFromInterestPerSecond(uint64 interestPerSecond) internal pure returns (uint64 interestPerYearBips) {
        return (interestPerSecond * 100) / 316880878;
    }

    function getUserBorrowAmount(ICauldronV2 cauldron, address user) internal view returns (uint256 borrowAmount) {
        Rebase memory totalBorrow = getTotalBorrowWithAccruedInterests(cauldron);
        return (cauldron.userBorrowPart(user) * totalBorrow.elastic) / totalBorrow.base;
    }

    // total borrow with on-fly accrued interests
    function getTotalBorrowWithAccruedInterests(ICauldronV2 cauldron) internal view returns (Rebase memory totalBorrow) {
        totalBorrow = cauldron.totalBorrow();
        (uint64 lastAccrued, , uint64 INTEREST_PER_SECOND) = cauldron.accrueInfo();
        uint256 elapsedTime = block.timestamp - lastAccrued;

        if (elapsedTime != 0 && totalBorrow.base != 0) {
            totalBorrow.elastic = totalBorrow.elastic + uint128((uint256(totalBorrow.elastic) * INTEREST_PER_SECOND * elapsedTime) / 1e18);
        }
    }

    function getOracleExchangeRate(ICauldronV2 cauldron) internal view returns (uint256) {
        IOracle oracle = IOracle(cauldron.oracle());
        bytes memory oracleData = cauldron.oracleData();
        return oracle.peekSpot(oracleData);
    }

    function getUserCollateral(ICauldronV2 cauldron, address account) internal view returns (uint256 amount, uint256 value) {
        IBentoBoxV1 bentoBox = IBentoBoxV1(cauldron.bentoBox());
        uint256 share = cauldron.userCollateralShare(account);

        amount = bentoBox.toAmount(cauldron.collateral(), share, false);
        value = (amount * EXCHANGE_RATE_PRECISION) / getOracleExchangeRate(cauldron);
    }

    function getUserPositionInfo(
        ICauldronV2 cauldron,
        address account
    )
        internal
        view
        returns (
            uint256 ltvBps,
            uint256 healthFactor,
            uint256 borrowValue,
            uint256 collateralValue,
            uint256 liquidationPrice,
            uint256 collateralAmount
        )
    {
        (collateralAmount, collateralValue) = getUserCollateral(cauldron, account);

        borrowValue = getUserBorrowAmount(cauldron, account);

        if (collateralValue > 0) {
            ltvBps = (borrowValue * BPS_PRECISION) / collateralValue;
            uint256 COLLATERALIZATION_RATE = cauldron.COLLATERIZATION_RATE(); // 1e5 precision

            // example with WBTC (8 decimals)
            // 18 + 8 + 5 - 5 - 8 - 10 = 8 decimals
            IERC20 collateral = cauldron.collateral();
            uint256 collateralPrecision = 10 ** collateral.safeDecimals();

            liquidationPrice =
                (borrowValue * collateralPrecision ** 2 * 1e5) /
                COLLATERALIZATION_RATE /
                collateralAmount /
                EXCHANGE_RATE_PRECISION;

            healthFactor = MathLib.subWithZeroFloor(
                EXCHANGE_RATE_PRECISION,
                (EXCHANGE_RATE_PRECISION * liquidationPrice * getOracleExchangeRate(cauldron)) / collateralPrecision ** 2
            );
        }
    }

    /// @notice the liquidator will get "MIM borrowPart" worth of collateral + liquidation fee incentive but borrowPart needs to be adjusted to take in account
    /// the sSpell distribution taken off the liquidation fee. This function takes in account the bad debt repayment in case
    /// the borrowPart give less collateral than it should.
    /// @param cauldron Cauldron contract
    /// @param account Account to liquidate
    /// @param borrowPart Amount of MIM debt to liquidate
    /// @return collateralAmount Amount of collateral that the liquidator will receive
    /// @return adjustedBorrowPart Adjusted borrowPart to take in account position with bad debt where the
    ///                            borrowPart give out more collateral than what the user has.
    /// @return requiredMim MIM amount that the liquidator will need to pay back to get the collateralShare
    function getLiquidationCollateralAndBorrowAmount(
        ICauldronV2 cauldron,
        address account,
        uint256 borrowPart
    ) internal view returns (uint256 collateralAmount, uint256 adjustedBorrowPart, uint256 requiredMim) {
        uint256 exchangeRate = getOracleExchangeRate(cauldron);
        Rebase memory totalBorrow = getTotalBorrowWithAccruedInterests(cauldron);
        IBentoBoxV1 box = IBentoBoxV1(cauldron.bentoBox());
        uint256 collateralShare = cauldron.userCollateralShare(account);
        IERC20 collateral = cauldron.collateral();

        // cap to the maximum amount of debt that can be liquidated in case the cauldron has bad debt
        {
            Rebase memory bentoBoxTotals = box.totals(collateral);

            // how much debt can be liquidated
            uint256 maxBorrowPart = (bentoBoxTotals.toElastic(collateralShare, false) * 1e23) /
                (cauldron.LIQUIDATION_MULTIPLIER() * exchangeRate);
            maxBorrowPart = totalBorrow.toBase(maxBorrowPart, false);

            if (borrowPart > maxBorrowPart) {
                borrowPart = maxBorrowPart;
            }
        }

        // convert borrowPart to debt
        requiredMim = totalBorrow.toElastic(borrowPart, false);

        // convert borrowPart to collateralShare
        {
            Rebase memory bentoBoxTotals = box.totals(collateral);

            // how much collateral share the liquidator will get from the given borrow amount
            collateralShare = bentoBoxTotals.toBase(
                (requiredMim * cauldron.LIQUIDATION_MULTIPLIER() * exchangeRate) /
                    (LIQUIDATION_MULTIPLIER_PRECISION * EXCHANGE_RATE_PRECISION),
                false
            );
            collateralAmount = box.toAmount(collateral, collateralShare, false);
        }

        // add the sSpell distribution part
        {
            requiredMim +=
                ((((requiredMim * cauldron.LIQUIDATION_MULTIPLIER()) / LIQUIDATION_MULTIPLIER_PRECISION) - requiredMim) *
                    DISTRIBUTION_PART) /
                DISTRIBUTION_PRECISION;

            IERC20 mim = cauldron.magicInternetMoney();

            // convert back and forth to amount to compensate for rounded up toShare conversion inside `liquidate`
            requiredMim = box.toAmount(mim, box.toShare(mim, requiredMim, true), true);
        }

        adjustedBorrowPart = borrowPart;
    }

    function isSolvent(ICauldronV2 cauldron, address account) internal view returns (bool) {
        IBentoBoxV1 bentoBox = IBentoBoxV1(cauldron.bentoBox());
        Rebase memory totalBorrow = getTotalBorrowWithAccruedInterests(cauldron);
        uint256 exchangeRate = getOracleExchangeRate(cauldron);
        IERC20 collateral = cauldron.collateral();
        uint256 COLLATERIZATION_RATE = cauldron.COLLATERIZATION_RATE();
        uint256 collateralShare = cauldron.userCollateralShare(account);
        uint256 borrowPart = cauldron.userBorrowPart(account);

        if (borrowPart == 0) {
            return true;
        } else if (collateralShare == 0) {
            return false;
        } else {
            return
                bentoBox.toAmount(
                    collateral,
                    (collateralShare * (EXCHANGE_RATE_PRECISION / COLLATERIZATION_RATE_PRECISION)) * COLLATERIZATION_RATE,
                    false
                ) >= (borrowPart * totalBorrow.elastic * exchangeRate) / totalBorrow.base;
        }
    }

    function getCollateralPrice(ICauldronV2 cauldron) internal view returns (uint256) {
        IERC20 collateral = cauldron.collateral();
        uint256 collateralPrecision = 10 ** collateral.safeDecimals();
        return (collateralPrecision * collateralPrecision) / getOracleExchangeRate(cauldron);
    }

    function decodeInitData(
        bytes calldata data
    )
        internal
        pure
        returns (
            address collateral,
            address oracle,
            bytes memory oracleData,
            uint64 INTEREST_PER_SECOND,
            uint256 LIQUIDATION_MULTIPLIER,
            uint256 COLLATERIZATION_RATE,
            uint256 BORROW_OPENING_FEE
        )
    {
        (collateral, oracle, oracleData, INTEREST_PER_SECOND, LIQUIDATION_MULTIPLIER, COLLATERIZATION_RATE, BORROW_OPENING_FEE) = abi
            .decode(data, (address, address, bytes, uint64, uint256, uint256, uint256));
    }
}
