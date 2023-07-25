// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "layerzerolabs-solidity-examples/token/oft/v2/IOFTV2.sol";

interface IOFTWrapper {
    event WrapperFeeWithdrawn(address to, uint256 amount);

    enum QUOTE_TYPE {
        ORACLE,
        FIXED_EXCHANGE_RATE
    }

    function sendOFTV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        QUOTE_TYPE _quote_type,
        IOFTV2.LzCallParams calldata _callParams
    ) external payable;

    function sendProxyOFTV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        QUOTE_TYPE _quote_type,
        IOFTV2.LzCallParams calldata _callParams
    ) external payable;

    function estimateSendFeeV2(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        bool _useZro,
        QUOTE_TYPE _quote_type,
        bytes calldata _adapterParams
    ) external view returns (uint nativeFee, uint zroFee);
}