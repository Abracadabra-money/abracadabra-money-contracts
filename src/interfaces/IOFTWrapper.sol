// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "interfaces/ILzCommonOFT.sol";
import "interfaces/IAggregator.sol";

interface IOFTWrapper {
    event LogWrapperFeeWithdrawn(address to, uint256 amount);
    event LogDefaultExchangeRateChanged(uint256 oldExchangeRate, uint256 newExchangeRate);
    event LogOracleImplementationChange(IAggregator indexed oldOracle, IAggregator indexed newOracle);
    event LogDefaultQuoteTypeChanged(QUOTE_TYPE oldValue, QUOTE_TYPE newValue);
    event LogFeeToChange(address indexed oldAddress, address indexed newAddress);

    enum QUOTE_TYPE {
        ORACLE,
        FIXED_EXCHANGE_RATE
    }

    function sendOFTV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        ILzCommonOFT.LzCallParams calldata _callParams
    ) external payable;

    function sendProxyOFTV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        ILzCommonOFT.LzCallParams calldata _callParams
    ) external payable;

    function estimateSendFeeV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        bytes calldata _adapterParams
    ) external view returns (uint nativeFee, uint zroFee);
}