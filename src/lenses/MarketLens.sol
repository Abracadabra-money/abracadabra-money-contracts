// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {ICauldronV2} from "interfaces/ICauldronV2.sol";
import {ICauldronV3} from "interfaces/ICauldronV3.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {MathLib} from "libraries/MathLib.sol";
import {CauldronLib} from "libraries/CauldronLib.sol";

contract MarketLens {
    struct UserPosition {
        address cauldron;
        address account;
        uint256 ltvBps;
        uint256 healthFactor;
        uint256 borrowValue;
        AmountValue collateral;
        uint256 liquidationPrice;
    }

    struct MarketInfo {
        address cauldron;
        uint256 borrowFee;
        uint256 maximumCollateralRatio;
        uint256 liquidationFee;
        uint256 interestPerYear;
        uint256 marketMaxBorrow;
        uint256 userMaxBorrow;
        uint256 totalBorrowed;
        uint256 oracleExchangeRate;
        uint256 collateralPrice;
        AmountValue totalCollateral;
    }

    struct AmountValue {
        uint256 amount;
        uint256 value;
    }

    uint256 constant PRECISION = 1e18;
    uint256 constant TENK_PRECISION = 1e5;
    uint256 constant BPS_PRECISION = 1e4;

    function getBorrowFee(ICauldronV2 cauldron) public view returns (uint256) {
        return (cauldron.BORROW_OPENING_FEE() * BPS_PRECISION) / TENK_PRECISION;
    }

    function getMaximumCollateralRatio(ICauldronV2 cauldron) public view returns (uint256) {
        return (cauldron.COLLATERIZATION_RATE() * BPS_PRECISION) / TENK_PRECISION;
    }

    function getLiquidationFee(ICauldronV2 cauldron) public view returns (uint256) {
        uint256 liquidationFee = cauldron.LIQUIDATION_MULTIPLIER() - 100_000;
        return (liquidationFee * BPS_PRECISION) / TENK_PRECISION;
    }

    function getInterestPerYear(ICauldronV2 cauldron) public view returns (uint64) {
        (, , uint64 interestPerSecond) = cauldron.accrueInfo();
        return CauldronLib.getInterestPerYearFromInterestPerSecond(interestPerSecond);
    }

    function getMimInBentoBox(ICauldronV2 cauldron) private view returns (uint256 mimInBentoBox) {
        IBentoBoxV1 bentoBox = IBentoBoxV1(cauldron.bentoBox());
        IERC20 mim = IERC20(cauldron.magicInternetMoney());
        uint256 poolBalance = bentoBox.balanceOf(mim, address(cauldron));
        mimInBentoBox = bentoBox.toAmount(mim, poolBalance, false);
    }

    function getTokenInBentoBox(IBentoBoxV1 bentoBox, IERC20 token, address account) public view returns (uint256 share, uint256 amount) {
        return (bentoBox.balanceOf(token, account), bentoBox.toAmount(token, share, false));
    }

    function getMaxMarketBorrowForCauldronV2(ICauldronV2 cauldron) public view returns (uint256) {
        return getMimInBentoBox(cauldron);
    }

    function getMaxUserBorrowForCauldronV2(ICauldronV2 cauldron) public view returns (uint256) {
        return getMimInBentoBox(cauldron);
    }

    // Returns the maximum amount that can be borrowed across all users
    function getMaxMarketBorrowForCauldronV3(ICauldronV3 cauldron) public view returns (uint256) {
        (uint256 totalBorrowLimit, ) = cauldron.borrowLimit();

        uint256 mimInBentoBox = getMimInBentoBox(cauldron);
        uint256 remainingBorrowLimit = MathLib.subWithZeroFloor(totalBorrowLimit, getTotalBorrowed(cauldron));

        return MathLib.min(mimInBentoBox, remainingBorrowLimit);
    }

    // Returns the maximum amount that a single user can borrow
    function getMaxUserBorrowForCauldronV3(ICauldronV3 cauldron) public view returns (uint256) {
        (uint256 totalBorrowLimit, uint256 userBorrowLimit) = cauldron.borrowLimit();

        uint256[] memory values = new uint256[](3);
        values[0] = getMimInBentoBox(cauldron);
        values[1] = MathLib.subWithZeroFloor(totalBorrowLimit, getTotalBorrowed(cauldron));
        values[2] = userBorrowLimit;

        return MathLib.min(values);
    }

    function getTotalBorrowed(ICauldronV2 cauldron) public view returns (uint256) {
        return CauldronLib.getTotalBorrowWithAccruedInterests(cauldron).elastic;
    }

    function getOracleExchangeRate(ICauldronV2 cauldron) public view returns (uint256) {
        return CauldronLib.getOracleExchangeRate(cauldron);
    }

    function getCollateralPrice(ICauldronV2 cauldron) public view returns (uint256) {
        return CauldronLib.getCollateralPrice(cauldron);
    }

    function getTotalCollateral(ICauldronV2 cauldron) public view returns (AmountValue memory) {
        IBentoBoxV1 bentoBox = IBentoBoxV1(cauldron.bentoBox());
        uint256 amount = bentoBox.toAmount(cauldron.collateral(), cauldron.totalCollateralShare(), false);
        uint256 value = (amount * PRECISION) / getOracleExchangeRate(cauldron);
        return AmountValue(amount, value);
    }

    function getUserBorrow(ICauldronV2 cauldron, address account) public view returns (uint256) {
        return CauldronLib.getUserBorrowAmount(cauldron, account);
    }

    function getUserMaxBorrow(ICauldronV2 cauldron, address account) public view returns (uint256) {
        (, uint256 value) = CauldronLib.getUserCollateral(cauldron, account);
        return (value * getMaximumCollateralRatio(cauldron)) / TENK_PRECISION;
    }

    function getUserCollateral(ICauldronV2 cauldron, address account) public view returns (AmountValue memory) {
        (uint256 amount, uint256 value) = CauldronLib.getUserCollateral(cauldron, account);
        return AmountValue(amount, value);
    }

    function getUserLtv(ICauldronV2 cauldron, address account) public view returns (uint256 ltvBps) {
        (ltvBps, , , , , ) = CauldronLib.getUserPositionInfo(cauldron, account);
    }

    function getHealthFactor(ICauldronV2 cauldron, address account, bool isStable) public view returns (uint256) {
        (, uint256 healthFactor, , , , ) = CauldronLib.getUserPositionInfo(cauldron, account);
        return isStable ? healthFactor * 10 : healthFactor;
    }

    function getUserLiquidationPrice(ICauldronV2 cauldron, address account) public view returns (uint256 liquidationPrice) {
        (, , , , liquidationPrice, ) = CauldronLib.getUserPositionInfo(cauldron, account);
    }

    function getUserPosition(ICauldronV2 cauldron, address account) public view returns (UserPosition memory) {
        (
            uint256 ltvBps,
            uint256 healthFactor,
            uint256 borrowValue,
            uint256 collateralValue,
            uint256 liquidationPrice,
            uint256 collateralAmount
        ) = CauldronLib.getUserPositionInfo(cauldron, account);

        return
            UserPosition(
                address(cauldron),
                address(account),
                ltvBps,
                healthFactor,
                borrowValue,
                AmountValue({amount: collateralAmount, value: collateralValue}),
                liquidationPrice
            );
    }

    // Get many user position information at once.
    // Beware of hitting RPC `eth_call` gas limit
    function getUserPositions(ICauldronV2 cauldron, address[] calldata accounts) public view returns (UserPosition[] memory positions) {
        positions = new UserPosition[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            positions[i] = getUserPosition(cauldron, accounts[i]);
        }
    }

    function getMarketInfoCauldronV2(ICauldronV2 cauldron) public view returns (MarketInfo memory) {
        return
            MarketInfo({
                cauldron: address(cauldron),
                borrowFee: getBorrowFee(cauldron),
                maximumCollateralRatio: getMaximumCollateralRatio(cauldron),
                liquidationFee: getLiquidationFee(cauldron),
                interestPerYear: getInterestPerYear(cauldron),
                marketMaxBorrow: getMaxMarketBorrowForCauldronV2(cauldron),
                userMaxBorrow: getMaxUserBorrowForCauldronV2(cauldron),
                totalBorrowed: getTotalBorrowed(cauldron),
                oracleExchangeRate: getOracleExchangeRate(cauldron),
                collateralPrice: getCollateralPrice(cauldron),
                totalCollateral: getTotalCollateral(cauldron)
            });
    }

    function getMarketInfoCauldronV3(ICauldronV3 cauldron) public view returns (MarketInfo memory marketInfo) {
        marketInfo = getMarketInfoCauldronV2(cauldron);
        marketInfo.marketMaxBorrow = getMaxMarketBorrowForCauldronV3(cauldron);
        marketInfo.userMaxBorrow = getMaxUserBorrowForCauldronV3(cauldron);
    }
}
