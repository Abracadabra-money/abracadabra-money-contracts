// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IMagicLP {
    function _BASE_TOKEN_() external view returns (address);

    function _QUOTE_TOKEN_() external view returns (address);

    function init(
        address maintainer,
        address baseTokenAddress,
        address quoteTokenAddress,
        uint256 lpFeeRate,
        address mtFeeRateModel,
        uint256 i,
        uint256 k
    ) external;

    function sellBase(address to) external returns (uint256 receiveQuoteAmount);

    function sellQuote(address to) external returns (uint256 receiveBaseAmount);

    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}
