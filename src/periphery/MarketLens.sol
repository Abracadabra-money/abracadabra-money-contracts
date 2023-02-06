// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log

import "interfaces/IBentoBoxV1.sol";
import "interfaces/ICauldronV2.sol";
import "BoringSolidity/interfaces/IERC20.sol";
import "utils/CauldronLib.sol";
import "libraries/MathLib.sol";

contract MarketLens {
    struct UserPosition {
        uint256 ltvBps;
        uint256 borrowValue;
        AmountValue collateralValue;
        uint256 liquidationPrice;
    }

    struct MarketInfo {
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

    function getMaxBorrowForCauldronV2User(ICauldronV2 cauldron) public view returns (uint256) {
        return getMimInBentoBox(cauldron);
    }

    function getBorrowLimitForCauldronV3User(ICauldronV3 cauldron) private view returns (uint256) {
        (uint256 totalLimit, uint256 borrowPartPerAddress) = cauldron.borrowLimit();
        return MathLib.min(totalLimit, borrowPartPerAddress);
    }

    // Returns the maximum amount that can be borrowed across all users
    function getMaxBorrowForCauldronV3Market(ICauldronV3 cauldron) public view returns (uint256) {
        (uint256 totalLimit, ) = cauldron.borrowLimit();
        return MathLib.min(totalLimit, getMimInBentoBox(cauldron));
    }

    // Returns the maximum amount that a single user can borrow
    function getMaxBorrowForCauldronV3User(ICauldronV3 cauldron) public view returns (uint256) {
        uint256 mimInBentoBox = getMimInBentoBox(cauldron);
        uint256 userBorrowLimit = getBorrowLimitForCauldronV3User(cauldron);
        return MathLib.min(userBorrowLimit, mimInBentoBox);
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
        (ltvBps, , , , ) = CauldronLib.getUserPositionInfo(cauldron, account);
    }

    function getUserLiquidationPrice(ICauldronV2 cauldron, address account) public view returns (uint256 liquidationPrice) {
        (, , , liquidationPrice, ) = CauldronLib.getUserPositionInfo(cauldron, account);
    }

    function getUserPosition(ICauldronV2 cauldron, address account) public view returns (UserPosition memory) {
        (uint256 ltvBps, uint256 borrowValue, uint256 collateralValue, uint256 liquidationPrice, uint256 collateralAmount) = CauldronLib
            .getUserPositionInfo(cauldron, account);

        return UserPosition(ltvBps, borrowValue, AmountValue({amount: collateralAmount, value: collateralValue}), liquidationPrice);
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
                borrowFee: getBorrowFee(cauldron),
                maximumCollateralRatio: getMaximumCollateralRatio(cauldron),
                liquidationFee: getLiquidationFee(cauldron),
                interestPerYear: getInterestPerYear(cauldron),
                marketMaxBorrow: getMimInBentoBox(cauldron),
                userMaxBorrow: getMaxBorrowForCauldronV2User(cauldron),
                totalBorrowed: getTotalBorrowed(cauldron),
                oracleExchangeRate: getOracleExchangeRate(cauldron),
                collateralPrice: getCollateralPrice(cauldron),
                totalCollateral: getTotalCollateral(cauldron)
            });
    }

    function getMarketInfoCauldronV3(ICauldronV3 cauldron) public view returns (MarketInfo memory marketInfo) {
        marketInfo = getMarketInfoCauldronV2(cauldron);
        marketInfo.marketMaxBorrow = getMaxBorrowForCauldronV3Market(cauldron);
        marketInfo.userMaxBorrow = getMaxBorrowForCauldronV3User(cauldron);
    }
}
