// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {ILzApp, ILzCommonOFT} from "/interfaces/ILayerZero.sol";

contract GenericFeeCollector is OwnableOperators {
    using SafeTransferLib for address;

    constructor(address _owner) {
        _initializeOwner(_owner);
    }

    /////////////////////////////////////////////////////////////////////////////////
    // VIEWS
    /////////////////////////////////////////////////////////////////////////////////

    function estimateBridgingFee(uint256 amount) external view returns (uint256 fee, uint256 gas) {
        gas = ILzApp(address(lzOftv2)).minDstGasLookup(LZ_MAINNET_CHAINID, 0 /* packet type for sendFrom */);
        (fee, ) = lzOftv2.estimateSendFee(LZ_MAINNET_CHAINID, bridgeRecipient, amount, false, abi.encodePacked(uint16(1), uint256(gas)));
    }

    /////////////////////////////////////////////////////////////////////////////////
    // OPERATORS
    /////////////////////////////////////////////////////////////////////////////////

    function bridge(uint256 amount, uint256 fee, uint256 gas) external payable onlyOperators {
        if (fee > address(this).balance) {
            revert ErrNotEnoughNativeTokenToCoverFee();
        }

        ILzCommonOFT.LzCallParams memory lzCallParams = ILzCommonOFT.LzCallParams({
            refundAddress: payable(address(this)),
            zroPaymentAddress: address(0),
            adapterParams: abi.encodePacked(uint16(1), uint256(gas))
        });

        lzOftv2.sendFrom{value: fee}(
            address(this), // 'from' address to send tokens
            LZ_MAINNET_CHAINID, // mainnet remote LayerZero chainId
            bridgeRecipient, // 'to' address to send tokens
            amount, // amount of tokens to send (in wei)
            lzCallParams
        );
    }

    /////////////////////////////////////////////////////////////////////////////////
    // ADMIN
    /////////////////////////////////////////////////////////////////////////////////

    function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
    }

    function execute(address to, uint256 value, bytes calldata data) external onlyOwner returns (bytes memory result) {
        return Address.functionCallWithValue(to, data, value);
    }
}
