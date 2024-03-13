const tokenDeploymentNamePerNetwork = {
    "mainnet": "Mainnet_ProxyOFTV2",
    "bsc": "BSC_IndirectOFTV2",
    "polygon": "Polygon_IndirectOFTV2",
    "fantom": "Fantom_IndirectOFTV2",
    "optimism": "Optimism_IndirectOFTV2",
    "arbitrum": "Arbitrum_IndirectOFTV2",
    "avalanche": "Avalanche_IndirectOFTV2",
    "moonriver": "Moonriver_IndirectOFTV2",
    "kava": "Kava_IndirectOFTV2",
    "base": "Base_IndirectOFTV2",
    "linea": "Linea_IndirectOFTV2",
    "blast": "Blast_IndirectOFTV2"
};

const spellTokenDeploymentNamePerNetwork = {
    "mainnet": "Mainnet_Spell_ProxyOFTV2",
    "blast": "Blast_Spell_IndirectOFTV2"
};

const wrapperDeploymentNamePerNetwork = {
    // Using a wrapper to collect fees
    "mainnet": "Mainnet_OFTWrapper",
    "bsc": "BSC_OFTWrapper",
    "polygon": "Polygon_OFTWrapper",
    "fantom": "Fantom_OFTWrapper",
    "optimism": "Optimism_OFTWrapper",
    "arbitrum": "Arbitrum_OFTWrapper",
    "avalanche": "Avalanche_OFTWrapper",
    "moonriver": "Moonriver_OFTWrapper",
    "kava": "Kava_OFTWrapper",

    // Using native fee collection
    "base": undefined,
    "linea": undefined,
    "blast": undefined
};

const minterDeploymentNamePerNetwork = {
    "mainnet": undefined,
    
    // Anyswap Implementations
    "bsc": "BSC_ElevatedMinterBurner",
    "polygon": "Polygon_ElevatedMinterBurner",
    "fantom": "Fantom_ElevatedMinterBurner",
    "optimism": "Optimism_ElevatedMinterBurner",
    "arbitrum": "Arbitrum_ElevatedMinterBurner",
    "avalanche": "Avalanche_ElevatedMinterBurner",
    "moonriver": "Moonriver_ElevatedMinterBurner",

    // Abracadabra Implementations
    "kava": undefined,
    "base": undefined,
    "linea": undefined,
    "blast": undefined
};

const ownerPerNetwork = {
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

const precrimeDeploymentNamePerNetwork = {
    "mainnet": "Mainnet_Precrime",
    "bsc": "BSC_Precrime",
    "polygon": "Polygon_Precrime",
    "fantom": "Fantom_Precrime",
    "optimism": "Optimism_Precrime",
    "arbitrum": "Arbitrum_Precrime",
    "avalanche": "Avalanche_Precrime",
    "moonriver": "Moonriver_Precrime",
    "kava": "Kava_Precrime",
    "base": "Base_Precrime",
    "linea": "Linea_Precrime",
    "blast": "Blast_Precrime"
};

const spellPrecrimeDeploymentNamePerNetwork = {
    "mainnet": "Mainnet_Spell_Precrime",
    "blast": "Blast_Spell_Precrime"
};

const feeHandlerDeployments = {
    "mainnet": "Mainnet_OFTWrapper",
    "bsc": "BSC_OFTWrapper",
    "polygon": "Polygon_OFTWrapper",
    "fantom": "Fantom_OFTWrapper",
    "optimism": "Optimism_OFTWrapper",
    "arbitrum": "Arbitrum_OFTWrapper",
    "avalanche": "Avalanche_OFTWrapper",
    "moonriver": "Moonriver_OFTWrapper",
    "kava": "Kava_OFTWrapper",
    "base": "Base_FeeHandler",
    "linea": "Linea_FeeHandler",
    "blast": "Blast_FeeHandler"
};

const getApplicationConfig = async (hre, remoteNetwork, sendLibrary, receiveLibrary, applicationAddress) => {
    const { getNetworkConfigByLzChainId } = hre;

    const remoteChainId = getLzChainIdByNetworkName(remoteNetwork);
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

module.exports = {
    getApplicationConfig,
    tokenDeploymentNamePerNetwork,
    spellTokenDeploymentNamePerNetwork,
    wrapperDeploymentNamePerNetwork,
    minterDeploymentNamePerNetwork,
    ownerPerNetwork,
    precrimeDeploymentNamePerNetwork,
    spellPrecrimeDeploymentNamePerNetwork,
    feeHandlerDeployments
}