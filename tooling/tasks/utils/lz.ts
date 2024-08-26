import type { ethers } from "ethers";
import type { Tooling } from "../../tooling";

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

export const mimTokenDeploymentNamePerNetwork: { [key: string]: any } = {
    "mainnet": "Mainnet_MIM_ProxyOFTV2",
    "bsc": "BSC_MIM_IndirectOFTV2",
    "polygon": "Polygon_MIM_IndirectOFTV2",
    "fantom": "Fantom_MIM_IndirectOFTV2",
    "optimism": "Optimism_MIM_IndirectOFTV2",
    "arbitrum": "Arbitrum_MIM_IndirectOFTV2",
    "avalanche": "Avalanche_MIM_IndirectOFTV2",
    "moonriver": "Moonriver_MIM_IndirectOFTV2",
    "kava": "Kava_MIM_IndirectOFTV2",
    "base": "Base_MIM_IndirectOFTV2",
    "linea": "Linea_MIM_IndirectOFTV2",
    "blast": "Blast_MIM_IndirectOFTV2"
};

export const spellTokenDeploymentNamePerNetwork: { [key: string]: any } = {
    "mainnet": "Mainnet_SPELL_ProxyOFTV2",
    "arbitrum": "Arbitrum_SPELL_IndirectOFTV2",
    "avalanche": "Avalanche_SPELL_IndirectOFTV2",
    "fantom": "Fantom_SPELL_IndirectOFTV2",
};

export const wrapperDeploymentNamePerNetwork: { [key: string]: any } = {
    // Using a wrapper to collect fees
    "mainnet": "Mainnet_MIM_OFTWrapper",
    "bsc": "BSC_MIM_OFTWrapper",
    "polygon": "Polygon_MIM_OFTWrapper",
    "fantom": "Fantom_MIM_OFTWrapper",
    "optimism": "Optimism_MIM_OFTWrapper",
    "arbitrum": "Arbitrum_MIM_OFTWrapper",
    "avalanche": "Avalanche_MIM_OFTWrapper",
    "moonriver": "Moonriver_MIM_OFTWrapper",
    "kava": "Kava_MIM_OFTWrapper",

    // Using native fee collection
    "base": undefined,
    "linea": undefined,
    "blast": undefined
};

export const minterDeploymentNamePerNetwork: { [key: string]: any } = {
    "mainnet": undefined,

    // Anyswap Implementations
    "bsc": "BSC_MIM_ElevatedMinterBurner",
    "polygon": "Polygon_MIM_ElevatedMinterBurner",
    "fantom": "Fantom_MIM_ElevatedMinterBurner",
    "optimism": "Optimism_MIM_ElevatedMinterBurner",
    "arbitrum": "Arbitrum_MIM_ElevatedMinterBurner",
    "avalanche": "Avalanche_MIM_ElevatedMinterBurner",
    "moonriver": "Moonriver_MIM_ElevatedMinterBurner",

    // Abracadabra Implementations
    "kava": undefined,
    "base": undefined,
    "linea": undefined,
    "blast": undefined
};

export const ownerPerNetwork: { [key: string]: any } = {
    "mainnet": "0x5f0DeE98360d8200b20812e174d139A1a633EDd2",
    "bsc": "0x9d9bC38bF4A128530EA45A7d27D0Ccb9C2EbFaf6",
    "polygon": "0x7d847c4A0151FC6e79C6042D8f5B811753f4F66e",
    "fantom": "0xb4ad8B57Bd6963912c80FCbb6Baea99988543c1c",
    "optimism": "0x4217AA01360846A849d2A89809d450D10248B513",
    "arbitrum": "0xf46BB6dDA9709C49EfB918201D97F6474EAc5Aea",
    "avalanche": "0xae64A325027C3C14Cf6abC7818aA3B9c07F5C799",
    "moonriver": "0xfc88aa661C44B4EdE197644ba971764AC59AFa62",
    "kava": "0x1261894F79E6CF21bF7E586Af7905Ec173C8805b",
    "base": "0xF657dE126f9D7666b5FFE4756CcD9EB393d86a92",
    "linea": "0x1c063276CF810957cf0665903FAd20d008f4b404",
    "blast": "0xfED8589d09650dB3D30a568b1e194882549D78cF"
};

export const precrimeDeploymentNamePerNetwork: { [key: string]: any } = {
    "mainnet": "Mainnet_MIM_Precrime",
    "bsc": "BSC_MIM_Precrime",
    "polygon": "Polygon_MIM_Precrime",
    "fantom": "Fantom_MIM_Precrime",
    "optimism": "Optimism_MIM_Precrime",
    "arbitrum": "Arbitrum_MIM_Precrime",
    "avalanche": "Avalanche_MIM_Precrime",
    "moonriver": "Moonriver_MIM_Precrime",
    "kava": "Kava_MIM_Precrime",
    "base": "Base_MIM_Precrime",
    "linea": "Linea_MIM_Precrime",
    "blast": "Blast_MIM_Precrime"
};

export const spellPrecrimeDeploymentNamePerNetwork: { [key: string]: any } = {
    "mainnet": "Mainnet_SPELL_Precrime",
    "arbitrum": "Arbitrum_SPELL_Precrime",
    "avalanche": "Avalanche_SPELL_Precrime",
    "fantom": "Fantom_SPELL_Precrime"
};

export const mimFeeHandlerDeployments: { [key: string]: any } = {
    "mainnet": "Mainnet_MIM_OFTWrapper",
    "bsc": "BSC_MIM_OFTWrapper",
    "polygon": "Polygon_MIM_OFTWrapper",
    "fantom": "Fantom_MIM_OFTWrapper",
    "optimism": "Optimism_MIM_OFTWrapper",
    "arbitrum": "Arbitrum_MIM_OFTWrapper",
    "avalanche": "Avalanche_MIM_OFTWrapper",
    "moonriver": "Moonriver_MIM_OFTWrapper",
    "kava": "Kava_MIM_OFTWrapper",
    "base": "Base_MIM_FeeHandler",
    "linea": "Linea_MIM_FeeHandler",
    "blast": "Blast_MIM_FeeHandler"
};

export const spellFeeHandlerDeployments: { [key: string]: any } = {
    "mainnet": "Mainnet_SPELL_FeeHandler",
    "fantom": "Fantom_SPELL_FeeHandler",
    "arbitrum": "Arbitrum_SPELL_FeeHandler",
    "avalanche": "Avalanche_SPELL_FeeHandler",
};

export const getApplicationConfig = async (tooling: Tooling, remoteNetwork: string, sendLibrary: ethers.Contract, receiveLibrary: ethers.Contract, applicationAddress: `0x${string}`) => {
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
