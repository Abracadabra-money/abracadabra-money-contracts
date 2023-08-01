// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ILzFeeHandler {
    function getFee() external view returns (uint256);

    function estimateSendFee(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint256 _amount,
        bytes calldata _adapterParams
    ) external view returns (uint256 _fee);
}
