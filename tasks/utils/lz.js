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
};

module.exports = {
    getApplicationConfig,
    tokenDeploymentNamePerNetwork
}