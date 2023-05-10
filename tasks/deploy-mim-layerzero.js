module.exports = async function (taskArgs, hre) {
    const networks = ["mainnet", "bsc", "polygon", "fantom", "optimism", "arbitrum", "avalanche"];

    const contractNamePerNetwork = {
        "mainnet": "Mainnet_ProxyOFTV2",
        "bsc": "BSC_IndirectOFTV2",
        "polygon": "Polygon_IndirectOFTV2",
        "fantom": "Fantom_IndirectOFTV2",
        "optimism": "Optimism_IndirectOFTV2",
        "arbitrum": "Arbitrum_IndirectOFTV2",
        "avalanche": "Avalanche_IndirectOFTV2"
    };

    // TODO: set right destination min gas per source network to destination chain
    // For now, assume it's the same for all network <-> network
    const minDstGasPerNetworkPacketType1 = {
        "mainnet": 100_000,
        "bsc": 100_000,
        "polygon": 100_000,
        "fantom": 100_000,
        "optimism": 100_000,
        "arbitrum": 100_000,
        "avalanche": 100_000
    };

    await hre.run("forge-deploy-multichain", { script: "MIMLayerZero", broadcast: taskArgs.broadcast, verify: taskArgs.verify, networks });

    // Only run the following if we are broacasting
    if (taskArgs.broadcast) {
        for (const network of networks) {
            for (const targetNetwork of networks) {
                if (targetNetwork === network) continue;

                await hre.run("setMinDstGas", { network, targetNetwork, contract: contractNamePerNetwork[network], packetType: "1", minGas: minDstGasPerNetworkPacketType1[network].toString() });
                await hre.run("setTrustedRemote", { network, network, localContract: contractNamePerNetwork[network], remoteContract: contractNamePerNetwork[targetNetwork] });
            }
        }
    }
}