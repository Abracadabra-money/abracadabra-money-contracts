const shell = require('shelljs');

module.exports = async function (taskArgs, hre) {
    const { foundryDeployments } = hre;
    const networks = ["mainnet", "bsc", "polygon", "fantom", "optimism", "arbitrum", "avalanche", "moonriver"];

    const tokenDeploymentNamePerNetwork = {
        "mainnet": "Mainnet_ProxyOFTV2",
        "bsc": "BSC_IndirectOFTV2",
        "polygon": "Polygon_IndirectOFTV2",
        "fantom": "Fantom_IndirectOFTV2",
        "optimism": "Optimism_IndirectOFTV2",
        "arbitrum": "Arbitrum_IndirectOFTV2",
        "avalanche": "Avalanche_IndirectOFTV2",
        "moonriver": "Moonriver_IndirectOFTV2",
    };

    await shell.exec("yarn build");
    await hre.run("forge-deploy-multichain", { script: "MIMLayerZero", broadcast: taskArgs.broadcast, verify: taskArgs.verify, networks });

    // Only run the following if we are broacasting
    if (taskArgs.broadcast) {
        for (const srcNetwork of networks) {
            const minGas = srcNetwork === "mainnet" ? 100_000 : 50_000;

            for (const targetNetwork of networks) {
                if (targetNetwork === srcNetwork) continue;

                console.log(`[${srcNetwork}] Setting minDstGas for ${tokenDeploymentNamePerNetwork[srcNetwork]} to ${minDstGas} for ${tokenDeploymentNamePerNetwork[targetNetwork]}`);
                await hre.run("lzSetMinDstGas", { network: srcNetwork, targetNetwork, contract: tokenDeploymentNamePerNetwork[srcNetwork], packetType: "1", minGas: minGas.toString() });

                console.log(`[${srcNetwork}] Setting trusted remote for ${tokenDeploymentNamePerNetwork[srcNetwork]} to ${tokenDeploymentNamePerNetwork[targetNetwork]}`);
                await hre.run("lzSetTrustedRemote", { network: srcNetwork, targetNetwork, localContract: tokenDeploymentNamePerNetwork[srcNetwork], remoteContract: tokenDeploymentNamePerNetwork[targetNetwork] });
            }
        }
    }
}