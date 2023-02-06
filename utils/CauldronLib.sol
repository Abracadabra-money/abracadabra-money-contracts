// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringRebase.sol";
import "cauldrons/CauldronV3_2.sol";
import "cauldrons/CauldronV4.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ICauldronV3.sol";
import "interfaces/ICauldronV4.sol";

library CauldronLib {
    using BoringERC20 for IERC20;

    uint256 constant PRECISION = 1e18;
    uint256 constant BPS_PRECISION = 1e4;

    /// Cauldron percentages parameters are in bips unit
    /// Examples:
    ///  1 = 0.01%
    ///  10_000 = 100%
    ///  250 = 2.5%
    ///
    /// Adapted from original calculation. (variables are % values instead of bips):
    ///  ltv = ltv * 1e3;
    ///  borrowFee = borrowFee * (1e5 / 100);
    ///  interest = interest * (1e18 / (365.25 * 3600 * 24) / 100);
    ///  liquidationFee = liquidationFee * 1e3 + 1e5;
    function getCauldronParameters(
        IERC20 collateral,
        IOracle oracle,
        bytes memory oracleData,
        uint256 ltvBips,
        uint256 interestBips,
        uint256 borrowFeeBips,
        uint256 liquidationFeeBips
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                collateral,
                oracle,
                oracleData,
                getInterestPerSecond(interestBips),
                liquidationFeeBips * 1e1 + 1e5,
                ltvBips * 1e1,
                borrowFeeBips * 1e1
            );
    }

    /// @dev example: 200 is 2% interests
    function getInterestPerSecond(uint256 interestBips) internal pure returns (uint64 interestsPerSecond) {
        return uint64((interestBips * 316880878) / 100); // 316880878 is the precomputed integral part of 1e18 / (36525 * 3600 * 24)
    }

    function getInterestPerYearFromInterestPerSecond(uint64 interestPerSecond) internal pure returns (uint64 interestPerYearBips) {
        return (interestPerSecond * 100) / 316880878;
    }

    function getUserBorrowAmount(ICauldronV2 cauldron, address user) internal view returns (uint256 borrowPart) {
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
        value = (amount * PRECISION) / getOracleExchangeRate(cauldron);
    }

    function getUserPositionInfo(ICauldronV2 cauldron, address account)
        internal
        view
        returns (
            uint256 ltvBps,
            uint256 borrowValue,
            uint256 collateralValue,
            uint256 liquidationPrice,
            uint256 collateralAmount
        )
    {
        (collateralAmount, collateralValue) = getUserCollateral(cauldron, account);

        borrowValue = getUserBorrowAmount(cauldron, account);
        ltvBps = (borrowValue * BPS_PRECISION) / collateralValue;

        uint256 COLLATERIZATION_RATE = cauldron.COLLATERIZATION_RATE(); // 1e5 precision

        // example with WBTC (8 decimals)
        // 18 + 8 + 5 - 5 - 8 - 10 = 8 decimals
        IERC20 collateral = cauldron.collateral();
        uint collateralPrecision = 10 ** collateral.safeDecimals();
        liquidationPrice = (borrowValue * collateralPrecision**2 * 1e5 ) / COLLATERIZATION_RATE / collateralAmount / PRECISION;
    }

    function getCollateralPrice(ICauldronV2 cauldron) internal view returns (uint256) {
        IERC20 collateral = cauldron.collateral();
        uint collateralPrecision = 10 ** collateral.safeDecimals();
        return PRECISION * collateralPrecision / getOracleExchangeRate(cauldron);
    }

    function decodeInitData(bytes calldata data)
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

    function deployCauldronV3(
        IBentoBoxV1 degenBox,
        address masterContract,
        IERC20 collateral,
        IOracle oracle,
        bytes memory oracleData,
        uint256 ltvBips,
        uint256 interestBips,
        uint256 borrowFeeBips,
        uint256 liquidationFeeBips
    ) internal returns (ICauldronV3 cauldron) {
        bytes memory data = getCauldronParameters(collateral, oracle, oracleData, ltvBips, interestBips, borrowFeeBips, liquidationFeeBips);
        return ICauldronV3(IBentoBoxV1(degenBox).deploy(masterContract, data, true));
    }

    function deployCauldronV4(
        IBentoBoxV1 degenBox,
        address masterContract,
        IERC20 collateral,
        IOracle oracle,
        bytes memory oracleData,
        uint256 ltvBips,
        uint256 interestBips,
        uint256 borrowFeeBips,
        uint256 liquidationFeeBips
    ) internal returns (ICauldronV4 cauldron) {
        bytes memory data = getCauldronParameters(collateral, oracle, oracleData, ltvBips, interestBips, borrowFeeBips, liquidationFeeBips);
        return ICauldronV4(IBentoBoxV1(degenBox).deploy(masterContract, data, true));
    }
}
