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

    function getInterestPerYear(ICauldronV2 cauldron) external view returns (uint64) {
        (, , uint64 interestPerSecond) = cauldron.accrueInfo();
        return CauldronLib.getInterestPerYearFromInterestPerSecond(interestPerSecond);
    }

    function getLiquidationFee(ICauldronV2 cauldron) public view returns (uint256) {
        return cauldron.LIQUIDATION_MULTIPLIER() - 100_000;
    }

    function getBorrowFee(ICauldronV2 cauldron) public view returns (uint256) {
        return cauldron.BORROW_OPENING_FEE();
    }

    function getMaximumCollateralRatio(ICauldronV2 cauldron) public view returns (uint256) {
        return cauldron.COLLATERIZATION_RATE();
    }

    function getMaxBorrowForCauldronV2(ICauldronV2 cauldron) external view returns (uint256) {
        IBentoBoxV1 bentoBox = IBentoBoxV1(cauldron.bentoBox());
        IERC20 mim = IERC20(cauldron.magicInternetMoney());
        uint256 poolBalance = bentoBox.balanceOf(mim, address(cauldron));
        return bentoBox.toAmount(mim, poolBalance, false);
    }

    function getMaxBorrowForCauldronV3(ICauldronV3 cauldron) public view returns (uint256) {
        IBentoBoxV1 bentoBox = IBentoBoxV1(cauldron.bentoBox());
        IERC20 mim = IERC20(cauldron.magicInternetMoney());
        uint256 poolBalance = bentoBox.balanceOf(mim, address(cauldron));
        uint256 mimInBentoBox = bentoBox.toAmount(mim, poolBalance, false);
        uint256 userBorrowLimit = getUserBorrowLimit(cauldron);
        return MathLib.min(userBorrowLimit, mimInBentoBox);
    }

    function getUserBorrowLimit(ICauldronV3 cauldron) public view returns (uint256) {
        (uint256 totalLimit, uint256 borrowPartPerAddress) = cauldron.borrowLimit();
        return MathLib.min(totalLimit, borrowPartPerAddress);
    }

    function getTotalMimBorrowed(ICauldronV2 cauldron) external view returns (uint256) {
        Rebase memory totalBorrow = cauldron.totalBorrow();
        return totalBorrow.elastic;
    }

    function getTvl(ICauldronV2 cauldron) external view returns (uint256) {
        IBentoBoxV1 bentoBox = IBentoBoxV1(cauldron.bentoBox());
        uint256 totalCollateralShare = cauldron.totalCollateralShare();

        uint256 totalTokensDeposited = bentoBox.toAmount(cauldron.collateral(), totalCollateralShare, false);
        return (totalTokensDeposited * PRECISION) / getOracleExchangeRate(cauldron);
    }

    function getOracleExchangeRate(ICauldronV2 cauldron) public view returns (uint256) {
        IOracle oracle = IOracle(cauldron.oracle());
        bytes memory oracleData = cauldron.oracleData();
        return oracle.peekSpot(oracleData);
    }

    function getUserBorrow(ICauldronV2 cauldron, address wallet) public view returns (uint256) {
        Rebase memory totalBorrow = cauldron.totalBorrow();
        uint256 userBorrowPart = cauldron.userBorrowPart(wallet);
        return (userBorrowPart * totalBorrow.elastic) / totalBorrow.base;
    }

    function getUserCollateral(ICauldronV2 cauldron, address wallet) public view returns (uint256 amount, uint256 value) {
        IBentoBoxV1 bentoBox = IBentoBoxV1(cauldron.bentoBox());
        uint256 exchangeRate = getOracleExchangeRate(cauldron);
        uint256 share = cauldron.userCollateralShare(wallet);

        amount = bentoBox.toAmount(cauldron.collateral(), share, false);
        value = (amount * PRECISION) / exchangeRate;
    }
}
