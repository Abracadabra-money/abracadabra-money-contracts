pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

interface IMarketLens {
    function getBorrowFee(address cauldron) external view returns (uint256);

    function getCollateralPrice(address cauldron) external view returns (uint256);

    function getInterestPerYear(address cauldron) external view returns (uint64);

    function getLiquidationFee(address cauldron) external view returns (uint256);

    function getMarketInfoCauldronV2(address cauldron) external view returns (MarketInfo memory);

    function getMarketInfoCauldronV3(address cauldron) external view returns (MarketInfo memory marketInfo);

    function getMaxMarketBorrowForCauldronV2(address cauldron) external view returns (uint256);

    function getMaxMarketBorrowForCauldronV3(address cauldron) external view returns (uint256);

    function getMaxUserBorrowForCauldronV2(address cauldron) external view returns (uint256);

    function getMaxUserBorrowForCauldronV3(address cauldron) external view returns (uint256);

    function getMaximumCollateralRatio(address cauldron) external view returns (uint256);

    function getOracleExchangeRate(address cauldron) external view returns (uint256);

    function getTotalBorrowed(address cauldron) external view returns (uint256);

    function getTotalCollateral(address cauldron) external view returns (AmountValue memory);

    function getUserBorrow(address cauldron, address account) external view returns (uint256);

    function getUserCollateral(address cauldron, address account) external view returns (AmountValue memory);

    function getUserLiquidationPrice(address cauldron, address account) external view returns (uint256 liquidationPrice);

    function getUserLtv(address cauldron, address account) external view returns (uint256 ltvBps);

    function getUserMaxBorrow(address cauldron, address account) external view returns (uint256);

    function getUserPosition(address cauldron, address account) external view returns (UserPosition memory);

    function getUserPositions(address cauldron, address[] memory accounts) external view returns (UserPosition[] memory positions);

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

    struct UserPosition {
        uint256 ltvBps;
        uint256 borrowValue;
        AmountValue collateralValue;
        uint256 liquidationPrice;
    }
}
