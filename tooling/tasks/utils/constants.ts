import { BigNumber } from "ethers";

export const WAD = BigNumber.from(1000000000000000000n);

export const LZ_ENDPOINT_ABI = [
    "function defaultSendVersion() view returns (uint16)",
    "function defaultReceiveVersion() view returns (uint16)",
    "function defaultSendLibrary() view returns (address)",
    "function defaultReceiveLibraryAddress() view returns (address)",
    "function uaConfigLookup(address) view returns (tuple(uint16 sendVersion, uint16 receiveVersion, address receiveLibraryAddress, address sendLibrary))"
];

export const LZ_MESSAGING_LIBRARY_ABI = [
    "function appConfig(address, uint16) view returns (tuple(uint16 inboundProofLibraryVersion, uint64 inboundBlockConfirmations, address relayer, uint16 outboundProofType, uint64 outboundBlockConfirmations, address oracle))",
    "function defaultAppConfig(uint16) view returns (tuple(uint16 inboundProofLibraryVersion, uint64 inboundBlockConfirmations, address relayer, uint16 outboundProofType, uint64 outboundBlockConfirmations, address oracle))"
];

export const LZ_USER_APPLICATION_ABI = [
    "function setConfig(uint16 _version, uint16 _chainId, uint _configType, bytes calldata _config)",
    "function setSendVersion(uint16 _version)",
    "function setReceiveVersion(uint16 _version)"
];
