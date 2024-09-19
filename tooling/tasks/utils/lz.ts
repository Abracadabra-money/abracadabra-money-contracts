import type {ethers} from "ethers";
import type {Tooling} from "../../tooling";
import {NetworkName, getNetworkNameEnumKey} from "../../types";

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

type BaseLzDeployementConfigs = {
    [key in string]: {
        [key in NetworkName]?: {
            nativeToken?: string;
            useWrapper?: boolean;
            useAnyswapMinterBurner?: boolean;
            owner: string;
            useNativeFeeHandler?: boolean;
        };
    };
};

type DeployementName = `${string}_${string}_${string}`;

export type LzDeployementConfig = {
    oft: DeployementName;
    oftWrapper: DeployementName;
    precrime: DeployementName;
    feeHandler: DeployementName;
    minterBurner?: DeployementName;
    owner: `0x${string}`;
    useWrapper: boolean;
    nativeToken?: `0x${string}`;
};

const LZ_DEPLOYEMENT_CONFIG: BaseLzDeployementConfigs = {
    MIM: {
        [NetworkName.Mainnet]: {
            nativeToken: "mim",
            useWrapper: true,
            owner: "safe.main",
        },
        [NetworkName.BSC]: {
            useWrapper: true,
            useAnyswapMinterBurner: true,
            owner: "safe.main",
        },
        [NetworkName.Polygon]: {
            useWrapper: true,
            useAnyswapMinterBurner: true,
            owner: "safe.main",
        },
        [NetworkName.Fantom]: {
            useWrapper: true,
            useAnyswapMinterBurner: true,
            owner: "safe.main",
        },
        [NetworkName.Optimism]: {
            useWrapper: true,
            useAnyswapMinterBurner: true,
            owner: "safe.main",
        },
        [NetworkName.Arbitrum]: {
            useWrapper: true,
            useAnyswapMinterBurner: true,
            owner: "safe.main",
        },
        [NetworkName.Avalanche]: {
            useWrapper: true,
            useAnyswapMinterBurner: true,
            owner: "safe.main",
        },
        [NetworkName.Moonriver]: {
            useWrapper: true,
            useAnyswapMinterBurner: true,
            owner: "safe.ops",
        },
        [NetworkName.Kava]: {
            useWrapper: true,
            owner: "safe.main",
        },
        [NetworkName.Base]: {
            useNativeFeeHandler: true,
            owner: "safe.ops",
        },
        [NetworkName.Linea]: {
            useNativeFeeHandler: true,
            owner: "safe.ops",
        },
        [NetworkName.Blast]: {
            useNativeFeeHandler: true,
            owner: "safe.main",
        },
    },

    SPELL: {
        [NetworkName.Mainnet]: {
            nativeToken: "spell",
            useNativeFeeHandler: true,
            owner: "safe.main",
        },
        [NetworkName.Fantom]: {
            useNativeFeeHandler: true,
            owner: "safe.main",
        },
        [NetworkName.Arbitrum]: {
            useNativeFeeHandler: true,
            owner: "safe.main",
        },
        [NetworkName.Avalanche]: {
            useNativeFeeHandler: true,
            owner: "safe.main",
        },
    },
};

const getSupportedNetworks = (tokenName: string): NetworkName[] => {
    if (!LZ_DEPLOYEMENT_CONFIG[tokenName]) {
        throw new Error(`No LZ deployment config found for token ${tokenName}`);
    }

    return Object.keys(LZ_DEPLOYEMENT_CONFIG[tokenName]) as NetworkName[];
};

const getDeployementConfig = (tooling: Tooling, tokenName: string, network: NetworkName): LzDeployementConfig => {
    const config = LZ_DEPLOYEMENT_CONFIG[tokenName]?.[network];
    if (!config) {
        throw new Error(`No LZ deployment config found for token ${tokenName} on network: ${network}`);
    }

    const networkEnumname = getNetworkNameEnumKey(network);

    let resolvedConfig: LzDeployementConfig = {} as LzDeployementConfig;

    if (config.nativeToken) {
        const addr = tooling.getAddressByLabel(network, config.nativeToken);
        if (!addr) {
            throw new Error(`No address found for token ${config.nativeToken} on network: ${network}`);
        }

        resolvedConfig.nativeToken = addr;
        resolvedConfig.oft = `${networkEnumname}_${tokenName}_${BASE_PROXY_OFTV2_DEPLOYEMENT_NAME}`;
    } else {
        resolvedConfig.oft = `${networkEnumname}_${tokenName}_${BASE_INDIRECT_OFTV2_DEPLOYEMENT_NAME}`;
    }

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
