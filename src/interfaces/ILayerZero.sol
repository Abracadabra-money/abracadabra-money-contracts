// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";
import {IAggregator} from "interfaces/IAggregator.sol";

interface ILzCommonOFT is IERC165 {
    struct LzCallParams {
        address payable refundAddress;
        address zroPaymentAddress;
        bytes adapterParams;
    }

    function estimateSendFee(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        bool _useZro,
        bytes calldata _adapterParams
    ) external view returns (uint nativeFee, uint zroFee);

    function estimateSendAndCallFee(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        bytes calldata _payload,
        uint64 _dstGasForCall,
        bool _useZro,
        bytes calldata _adapterParams
    ) external view returns (uint nativeFee, uint zroFee);

    function circulatingSupply() external view returns (uint);

    function token() external view returns (address);
}

interface ILzUserApplicationConfig {
    function setConfig(uint16 _version, uint16 _chainId, uint _configType, bytes calldata _config) external;

    function setSendVersion(uint16 _version) external;

    function setReceiveVersion(uint16 _version) external;

    function forceResumeReceive(uint16 _srcChainId, bytes calldata _srcAddress) external;
}

interface ILzEndpoint is ILzUserApplicationConfig {
    function defaultSendLibrary() external view returns (address);

    function send(
        uint16 _dstChainId,
        bytes calldata _destination,
        bytes calldata _payload,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    ) external payable;

    function receivePayload(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        address _dstAddress,
        uint64 _nonce,
        uint _gasLimit,
        bytes calldata _payload
    ) external;

    function getInboundNonce(uint16 _srcChainId, bytes calldata _srcAddress) external view returns (uint64);

    function getOutboundNonce(uint16 _dstChainId, address _srcAddress) external view returns (uint64);

    function estimateFees(
        uint16 _dstChainId,
        address _userApplication,
        bytes calldata _payload,
        bool _payInZRO,
        bytes calldata _adapterParam
    ) external view returns (uint nativeFee, uint zroFee);

    function getChainId() external view returns (uint16);

    function retryPayload(uint16 _srcChainId, bytes calldata _srcAddress, bytes calldata _payload) external;

    function hasStoredPayload(uint16 _srcChainId, bytes calldata _srcAddress) external view returns (bool);

    function getSendLibraryAddress(address _userApplication) external view returns (address);

    function getReceiveLibraryAddress(address _userApplication) external view returns (address);

    function isSendingPayload() external view returns (bool);

    function isReceivingPayload() external view returns (bool);

    function getConfig(uint16 _version, uint16 _chainId, address _userApplication, uint _configType) external view returns (bytes memory);

    function getSendVersion(address _userApplication) external view returns (uint16);

    function getReceiveVersion(address _userApplication) external view returns (uint16);

    function defaultSendVersion() external view returns (uint16);

    function defaultReceiveVersion() external view returns (uint16);

    function defaultReceiveLibraryAddress() external view returns (address);

    function uaConfigLookup(
        address _address
    ) external view returns (uint16 sendVersion, uint16 receiveVersion, address receiveLibraryAddress, address sendLibrary);
}

interface ILzBaseOFTV2 {
    function sharedDecimals() external view returns (uint8);

    function innerToken() external view returns (address);
}

interface ILzApp {
    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) external;

    function minDstGasLookup(uint16 _srcChainId, uint16 _dstChainId) external view returns (uint);

    function setTrustedRemote(uint16 _remoteChainId, bytes calldata _path) external;

    function trustedRemoteLookup(uint16 _srcChainId) external view returns (bytes memory);

    function setConfig(uint16 _version, uint16 _chainId, uint _configType, bytes calldata _config) external;

    function lzEndpoint() external view returns (ILzEndpoint);
}

interface ILzFeeHandler {
    enum QuoteType {
        None,
        Oracle,
        Fixed
    }

    function getFee() external view returns (uint256);
}

interface ILzOFTV2 is ILzCommonOFT {
    function sendFrom(
        address _from,
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        LzCallParams calldata _callParams
    ) external payable;

    function sendAndCall(
        address _from,
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        bytes calldata _payload,
        uint64 _dstGasForCall,
        LzCallParams calldata _callParams
    ) external payable;
}

interface ILzOFTReceiverV2 {
    function onOFTReceived(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes32 _from,
        uint _amount,
        bytes calldata _payload
    ) external;
}

interface ILzUltraLightNodeV2 {
    function defaultAppConfig(
        uint16
    )
        external
        view
        returns (
            uint16 inboundProofLibraryVersion,
            uint64 inboundBlockConfirmations,
            address relayer,
            uint16 outboundProofType,
            uint64 outboundBlockConfirmations,
            address oracle
        );

    function appConfig(
        address,
        uint16
    )
        external
        view
        returns (
            uint16 inboundProofLibraryVersion,
            uint64 inboundBlockConfirmations,
            address relayer,
            uint16 outboundProofType,
            uint64 outboundBlockConfirmations,
            address oracle
        );
}

interface ILzReceiver {
    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) external;
}

interface IOFTV2View {
    function lzReceive(uint16 _srcChainId, bytes32 _scrAddress, bytes memory _payload, uint _totalSupply) external view returns (uint);

    function getInboundNonce(uint16 _srcChainId) external view returns (uint64);

    function getCurrentState() external view returns (uint);

    function isProxy() external view returns (bool);
}

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

interface IPreCrimeView {
    struct Packet {
        uint16 srcChainId;
        bytes32 srcAddress;
        uint64 nonce;
        bytes payload;
    }

    struct SimulationResult {
        uint chainTotalSupply;
        bool isProxy;
    }

    function getConfig(Packet[] calldata _packets) external view returns (bytes memory);

    function precrime(Packet[] calldata _packets, bytes[] calldata _simulation) external view returns (uint16 code, bytes memory reason);

    function version() external view returns (uint16);

    function simulate(Packet[] calldata _packets) external view returns (uint16 code, bytes memory result);
}
