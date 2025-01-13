import type {ethers} from "ethers";
import type {Tooling} from "../../tooling";
import {NetworkName, getNetworkNameEnumKey} from "../../types";
import { LZ_DEPLOYEMENT_CONFIG } from "../../config";

export const CONFIG_TYPE_INBOUND_PROOF_LIBRARY_VERSION = 1;
export const CONFIG_TYPE_INBOUND_BLOCK_CONFIRMATIONS = 2;
export const CONFIG_TYPE_RELAYER = 3;
export const CONFIG_TYPE_OUTBOUND_PROOF_TYPE = 4;
export const CONFIG_TYPE_OUTBOUND_BLOCK_CONFIRMATIONS = 5;
export const CONFIG_TYPE_ORACLE = 6;

// https://layerzero.gitbook.io/docs/evm-guides/ua-custom-configuration#set-inbound-proof-library
// 1: MPT
// 2: Feather Proof
export const PROOF_LIBRARY_VERSION = 2;

// https://layerzero.gitbook.io/docs/ecosystem/oracle/google-cloud-oracle
export const UA_ORACLE_ADDRESS = "0xD56e4eAb23cb81f43168F9F45211Eb027b9aC7cc";

export const BASE_PROXY_OFTV2_DEPLOYEMENT_NAME = "ProxyOFTV2";
export const BASE_INDIRECT_OFTV2_DEPLOYEMENT_NAME = "IndirectOFTV2";
export const BASE_PRECRIME_OFTV2_DEPLOYEMENT_NAME = "Precrime";
export const BASE_ANYSWAP_MINTERBURNER_DEPLOYMENT_NAME = "ElevatedMinterBurner";
export const BASE_FEEHANDLE_DEPLOYMENT_NAME = "FeeHandler";
export const BASE_OFTV2_WRAPPER_DEPLOYEMENT_NAME = "OFTWrapper";

export type BaseLzDeployementConfigs = {
    [key in string]: {
        [key in NetworkName]?: {
            isNative?: boolean;
            useWrapper?: boolean;
            useAnyswapMinterBurner?: boolean;
            owner: string;
            useNativeFeeHandler?: boolean;
            token: string;
        };
    };
};

type DeployementName = `${string}_${string}_${string}`;

export type LzDeploymentConfig = {
    isNative: boolean;
    oft: DeployementName;
    oftWrapper: DeployementName;
    precrime: DeployementName;
    feeHandler: DeployementName;
    minterBurner?: DeployementName;
    owner: `0x${string}`;
    useWrapper: boolean;
    token: `0x${string}`;
};

const getSupportedNetworks = (tokenName: string): NetworkName[] => {
    if (!LZ_DEPLOYEMENT_CONFIG[tokenName]) {
        throw new Error(`No LZ deployment config found for token ${tokenName}`);
    }

    return Object.keys(LZ_DEPLOYEMENT_CONFIG[tokenName]) as NetworkName[];
};

const getDeployementConfig = (tooling: Tooling, tokenName: string, network: NetworkName): LzDeploymentConfig => {
    const config = LZ_DEPLOYEMENT_CONFIG[tokenName]?.[network];
    if (!config) {
        throw new Error(`No LZ deployment config found for token ${tokenName} on network: ${network}`);
    }

    const networkEnumname = getNetworkNameEnumKey(network);

    let resolvedConfig: LzDeploymentConfig = {} as LzDeploymentConfig;

    resolvedConfig.isNative = !!config.isNative;

    if (config.isNative) {
        resolvedConfig.oft = `${networkEnumname}_${tokenName}_${BASE_PROXY_OFTV2_DEPLOYEMENT_NAME}`;
    } else {
        resolvedConfig.oft = `${networkEnumname}_${tokenName}_${BASE_INDIRECT_OFTV2_DEPLOYEMENT_NAME}`;
    }

    const addr = tooling.getAddressByLabel(network, config.token);
    if (!addr) {
        throw new Error(`No address found for token ${config.token} on network: ${network}`);
    }

    resolvedConfig.token = addr;
    resolvedConfig.precrime = `${networkEnumname}_${tokenName}_${BASE_PRECRIME_OFTV2_DEPLOYEMENT_NAME}`;

    const owner = tooling.getAddressByLabel(network, config.owner);
    if (!owner) {
        throw new Error(`No address found for owner ${config.owner} on network: ${network}`);
    }
    resolvedConfig.owner = owner;

    if (config.useAnyswapMinterBurner) {
        resolvedConfig.minterBurner = `${networkEnumname}_${tokenName}_${BASE_ANYSWAP_MINTERBURNER_DEPLOYMENT_NAME}`;
    }

    resolvedConfig.useWrapper = config.useWrapper || false;

    if (config.useWrapper) {
        resolvedConfig.oftWrapper = `${networkEnumname}_${tokenName}_${BASE_OFTV2_WRAPPER_DEPLOYEMENT_NAME}`;
        resolvedConfig.feeHandler = resolvedConfig.oftWrapper;
    } else {
        resolvedConfig.feeHandler = `${networkEnumname}_${tokenName}_${BASE_FEEHANDLE_DEPLOYMENT_NAME}`;
    }

    return resolvedConfig;
};

const getApplicationConfig = async (
    tooling: Tooling,
    remoteNetwork: NetworkName,
    sendLibrary: ethers.Contract,
    receiveLibrary: ethers.Contract,
    applicationAddress: `0x${string}`
) => {
    const remoteChainId = tooling.getLzChainIdByName(remoteNetwork);
    const sendConfig = await sendLibrary.appConfig(applicationAddress, remoteChainId);

    let inboundProofLibraryVersion = sendConfig.inboundProofLibraryVersion;
    let inboundBlockConfirmations = sendConfig.inboundBlockConfirmations.toNumber();

    if (receiveLibrary) {
        const receiveConfig = await receiveLibrary.appConfig(applicationAddress, remoteChainId);
        inboundProofLibraryVersion = receiveConfig.inboundProofLibraryVersion;
        inboundBlockConfirmations = receiveConfig.inboundBlockConfirmations.toNumber();
    }
    return {
        remoteNetwork,
        inboundProofLibraryVersion,
        inboundBlockConfirmations,
        relayer: sendConfig.relayer,
        outboundProofType: sendConfig.outboundProofType,
        outboundBlockConfirmations: sendConfig.outboundBlockConfirmations.toNumber(),
        oracle: sendConfig.oracle,
    };
};

export const lz = {
    getApplicationConfig,
    getDeployementConfig,
    getSupportedNetworks,
};
