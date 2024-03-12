// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IMagicLP {
    function _BASE_TOKEN_() external view returns (address);

    function _QUOTE_TOKEN_() external view returns (address);

    function _BASE_RESERVE_() external view returns (uint112);

    function _QUOTE_RESERVE_() external view returns (uint112);

    function _BASE_TARGET_() external view returns (uint112);

    function _QUOTE_TARGET_() external view returns (uint112);

    function _I_() external view returns (uint256);

    function getReserves() external view returns (uint256 baseReserve, uint256 quoteReserve);

    function totalSupply() external view returns (uint256 totalSupply);

    function init(
        address baseTokenAddress,
        address quoteTokenAddress,
        uint256 lpFeeRate,
        address mtFeeRateModel,
        uint256 i,
        uint256 k,
        bool protocolOwnedPool
    ) external;

    function sellBase(address to) external returns (uint256 receiveQuoteAmount);

    function sellQuote(address to) external returns (uint256 receiveBaseAmount);

    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;

    function buyShares(address to) external returns (uint256 shares, uint256 baseInput, uint256 quoteInput);

    function sellShares(
        uint256 shareAmount,
        address to,
        uint256 baseMinAmount,
        uint256 quoteMinAmount,
        bytes calldata data,
        uint256 deadline
    ) external returns (uint256 baseAmount, uint256 quoteAmount);

    function MIN_LP_FEE_RATE() external view returns (uint256);

    function MAX_LP_FEE_RATE() external view returns (uint256);

    function _PAUSED_() external view returns (bool);

    function setPaused(bool paused) external;
}
