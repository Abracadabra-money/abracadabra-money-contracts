const { ethers } = require("ethers");

module.exports = async (taskArgs, hre) => {
    const { changeNetwork, getContractAt, getLzChainIdByNetworkName } = hre;

    let networks = taskArgs.networks.split(",");

    if (networks.length == 1 && networks[0] == "all") {
        networks = hre.getAllNetworksLzMimSupported();
    }

    const configByNetwork = [];
    for (let network of networks) {
        changeNetwork(network);

        const { addresses } = require(`../../config/${network}.json`);

        let endpointAddress = addresses.find(a => a.key === "LZendpoint");
        if (!endpointAddress) {
            console.log(`No LZendpoint address found for ${network}`);
            process.exit(1);
        }

        endpointAddress = endpointAddress.value;
        const endpoint = await getContractAt("ILzEndpoint", endpointAddress);

        console.log(`Getting config for ${network}...`);
        const sendVersion = await endpoint.defaultSendVersion();
        const receiveVersion = await endpoint.defaultReceiveVersion();
        const sendLibraryAddress = await endpoint.defaultSendLibrary();
        const messagingLibrary = await getContractAt(
            "ILzUltraLightNodeV2",
            sendLibraryAddress
        );

        const config = await messagingLibrary.defaultAppConfig(
            getLzChainIdByNetworkName(network));

        configByNetwork.push({
            network,
            sendVersion,
            receiveVersion,
            inboundProofLibraryVersion: config.inboundProofLibraryVersion,
            inboundBlockConfirmations: config.inboundBlockConfirmations.toNumber(),
            relayer: config.relayer,
            outboundProofType: config.outboundProofType,
            outboundBlockConfirmations: config.outboundBlockConfirmations.toNumber(),
            oracle: config.oracle,
        });
    }

    console.table(configByNetwork);
}
