// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log

import "interfaces/IBentoBoxV1.sol";
import "interfaces/ICauldronV2.sol";
import "BoringSolidity/interfaces/IERC20.sol";
import "utils/CauldronLib.sol";
import "libraries/MathLib.sol";

contract MarketLens {
    uint256 constant PRECISION = 1e18;

    function getInterestPerYear(ICauldronV2 cauldron) external view returns (uint64 interestPerYear) {
        (, , uint64 interestPerSecond) = cauldron.accrueInfo();
        interestPerYear = CauldronLib.getInterestPerYearFromInterestPerSecond(interestPerSecond);
    }

    function getLiquidationFee(ICauldronV2 cauldron) public view returns (uint256 liquidationFee) {
        liquidationFee = cauldron.LIQUIDATION_MULTIPLIER() - 100_000;
    }

    function getBorrowFee(ICauldronV2 cauldron) public view returns (uint256 borrowFee) {
        borrowFee = cauldron.BORROW_OPENING_FEE();
    }

    function getMaximumCollateralRatio(ICauldronV2 cauldron) public view returns (uint256 mcr) {
        mcr = cauldron.COLLATERIZATION_RATE();
    }

    function getMaxBorrowForCauldronV2(ICauldronV2 cauldron) external view returns (uint256 maxBorrow) {
        IBentoBoxV1 bentoBox = IBentoBoxV1(cauldron.bentoBox());
        IERC20 mim = IERC20(cauldron.magicInternetMoney());
        uint256 poolBalance = bentoBox.balanceOf(mim, address(cauldron));
        maxBorrow = bentoBox.toAmount(mim, poolBalance, false);
    }

    function getMaxBorrowForCauldronV3(ICauldronV3 cauldron) public view returns (uint256 maxBorrow) {
        IBentoBoxV1 bentoBox = IBentoBoxV1(cauldron.bentoBox());
        IERC20 mim = IERC20(cauldron.magicInternetMoney());
        uint256 poolBalance = bentoBox.balanceOf(mim, address(cauldron));
        uint256 mimInBentoBox = bentoBox.toAmount(mim, poolBalance, false);
        uint256 userBorrowLimit = getUserBorrowLimit(cauldron);
        maxBorrow = MathLib.min(userBorrowLimit, mimInBentoBox);
    }

    function getUserBorrowLimit(ICauldronV3 cauldron) public view returns (uint256 userBorrowLimit) {
        (uint256 totalLimit, uint256 borrowPartPerAddress) = cauldron.borrowLimit();
        userBorrowLimit = MathLib.min(totalLimit, borrowPartPerAddress);
    }

    function getTotalMimBorrowed(ICauldronV2 cauldron) external view returns (uint256 totalMimBorrowed) {
        Rebase memory totalBorrow = cauldron.totalBorrow();
        totalMimBorrowed = totalBorrow.elastic;
    }

    function getTvl(ICauldronV2 cauldron) external view returns (uint256 tvl) {
        IBentoBoxV1 bentoBox = IBentoBoxV1(cauldron.bentoBox());
        uint256 totalCollateralShare = cauldron.totalCollateralShare();

        uint256 totalTokensDeposited = bentoBox.toAmount(cauldron.collateral(), totalCollateralShare, false);
        tvl = (totalTokensDeposited * PRECISION) / getOracleExchangeRate(cauldron);
    }

    function getOracleExchangeRate(ICauldronV2 cauldron) public view returns (uint256 exchangeRate) {
        IOracle oracle = IOracle(cauldron.oracle());
        bytes memory oracleData = cauldron.oracleData();
        exchangeRate = oracle.peekSpot(oracleData);
    }

    function getUserBorrow(ICauldronV2 cauldron, address wallet) public view returns (uint256 amount) {
        Rebase memory totalBorrow = cauldron.totalBorrow();
        uint256 userBorrowPart = cauldron.userBorrowPart(wallet);
        amount = (userBorrowPart * totalBorrow.elastic) / totalBorrow.base;
    }

    function getUserCollateral(ICauldronV2 cauldron, address wallet) public view returns (uint256 amount, uint256 value) {
        IBentoBoxV1 bentoBox = IBentoBoxV1(cauldron.bentoBox());
        uint256 exchangeRate = getOracleExchangeRate(cauldron);
        uint256 share = cauldron.userCollateralShare(wallet);

        amount = bentoBox.toAmount(cauldron.collateral(), share, false);
        value = (amount * PRECISION) / exchangeRate;
        return (amount, value);
    }
}
