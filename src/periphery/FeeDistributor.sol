// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {ILzApp, ILzCommonOFT, ILzOFTV2} from "/interfaces/ILayerZero.sol";

contract FeeDistributor is OwnableOperators {
    using SafeTransferLib for address;

    error ErrNotEnoughNativeTokenToCoverFee();
    error ErrInvalidBridgePath(address oft, address recipient, uint16 lzChainId);
    error ErrInvalidRecipient(address recipient);

    event LogExchangeSet(address indexed exchange);
    event LogBridgePathSet(address indexed oft, address indexed recipient, uint16 lzChainId, bool enabled);
    event LogRecipientSet(address indexed recipient, bool enabled);

    mapping(address oft => mapping(address recipient => mapping(uint16 lzChainId => bool enabled))) public bridgePaths;
    mapping(address recipient => bool) public allowedRecipients;

    address public exchange;

    constructor(address _owner) {
        _initializeOwner(_owner);
    }

    /////////////////////////////////////////////////////////////////////////////////
    // VIEWS
    /////////////////////////////////////////////////////////////////////////////////

    function validateBridgePath(address oft, address recipient, uint16 lzChainId) internal view {
        if (!bridgePaths[oft][recipient][lzChainId]) {
            revert ErrInvalidBridgePath(oft, recipient, lzChainId);
        }
    }

    function estimateBridgingFee(
        ILzOFTV2 oft,
        uint16 toLzChainId,
        address recipient,
        uint256 amount
    ) external view returns (uint256 fee, uint256 gas) {
        gas = ILzApp(address(oft)).minDstGasLookup(toLzChainId, 0 /* packet type for sendFrom */);

        (fee, ) = oft.estimateSendFee(
            toLzChainId,
            bytes32(uint256(uint160(recipient))),
            amount,
            false,
            abi.encodePacked(uint16(1), uint256(gas))
        );
    }

    /////////////////////////////////////////////////////////////////////////////////
    // OPERATORS
    /////////////////////////////////////////////////////////////////////////////////

    function transfer(address token, address recipient, uint256 amount) external onlyOperators {
        if (!allowedRecipients[recipient]) {
            revert ErrInvalidRecipient(recipient);
        }

        token.safeTransfer(recipient, amount);
    }

    function swap(bytes memory data, uint256 value) external onlyOperators {
        Address.functionCallWithValue(exchange, data, value);
    }

    function bridge(
        ILzOFTV2 oft,
        uint16 toLzChainId,
        address recipient,
        uint256 amount,
        uint256 fee,
        uint256 gas
    ) external payable onlyOperators {
        validateBridgePath(address(oft), recipient, toLzChainId);

        if (fee > address(this).balance) {
            revert ErrNotEnoughNativeTokenToCoverFee();
        }

        ILzCommonOFT.LzCallParams memory lzCallParams = ILzCommonOFT.LzCallParams({
            refundAddress: payable(address(this)),
            zroPaymentAddress: address(0),
            adapterParams: abi.encodePacked(uint16(1), uint256(gas))
        });

        oft.sendFrom{value: fee}(
            address(this), // 'from' address to send tokens
            toLzChainId, // destination LayerZero chainId
            bytes32(uint256(uint160(recipient))), // 'to' address to send tokens
            amount, // amount of tokens to send (in wei)
            lzCallParams
        );
    }

    /////////////////////////////////////////////////////////////////////////////////
    // ADMIN
    /////////////////////////////////////////////////////////////////////////////////

    function setExchange(address _exchange) external onlyOwner {
        exchange = _exchange;
        emit LogExchangeSet(_exchange);
    }

    function setRecipient(address recipient, bool enabled) external onlyOwner {
        allowedRecipients[recipient] = enabled;
        emit LogRecipientSet(recipient, enabled);
    }

    function setAllowance(address token, address spender, uint256 amount) external onlyOwner {
        token.safeApprove(spender, amount);
    }

    function setBridgePath(address oft, address recipient, uint16 lzChainId, bool enabled) external onlyOwner {
        bridgePaths[oft][recipient][lzChainId] = enabled;
        emit LogBridgePathSet(oft, recipient, lzChainId, enabled);
    }

    function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
    }

    function execute(address to, uint256 value, bytes calldata data) external onlyOwner returns (bytes memory result) {
        return Address.functionCallWithValue(to, data, value);
    }
}
