const shell = require('shelljs');

module.exports = async function (taskArgs, hre) {
    // indicate here, networks to deploy on and configure
    //const networks = ["mainnet", "avalanche", "polygon", "fantom", "optimism", "arbitrum", "moonriver", "bsc", "kava", "base", "linea"];
    const networks = [ "linea"];

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

    await shell.exec("yarn build");
    await hre.run("forge-deploy-multichain", { script: "MIMLayerZero", broadcast: taskArgs.broadcast, verify: taskArgs.verify, networks, noConfirm: taskArgs.noConfirm, resume: taskArgs.resume });

    // Only run the following if we are broadcasting
    if (taskArgs.broadcast) {
        for (const srcNetwork of networks) {
            const minGas = 100_000;

            for (const targetNetwork of Object.keys(tokenDeploymentNamePerNetwork)) {
                if (targetNetwork === srcNetwork) continue;

                console.log(" -> ", targetNetwork);
                console.log(`[${srcNetwork}] PacketType 0 - Setting minDstGas for ${tokenDeploymentNamePerNetwork[srcNetwork]} to ${minGas} for ${tokenDeploymentNamePerNetwork[targetNetwork]}`);
                await hre.run("lzSetMinDstGas", { network: srcNetwork, targetNetwork, contract: tokenDeploymentNamePerNetwork[srcNetwork], packetType: "0", minGas: minGas.toString() });

                console.log(" -> ", targetNetwork);
                console.log(`[${srcNetwork}] PacketType 1 - Setting minDstGas for ${tokenDeploymentNamePerNetwork[srcNetwork]} to ${minGas} for ${tokenDeploymentNamePerNetwork[targetNetwork]}`);
                await hre.run("lzSetMinDstGas", { network: srcNetwork, targetNetwork, contract: tokenDeploymentNamePerNetwork[srcNetwork], packetType: "1", minGas: minGas.toString() });

                console.log(`[${srcNetwork}] Setting trusted remote for ${tokenDeploymentNamePerNetwork[srcNetwork]} to ${tokenDeploymentNamePerNetwork[targetNetwork]}`);
                await hre.run("lzSetTrustedRemote", { network: srcNetwork, targetNetwork, localContract: tokenDeploymentNamePerNetwork[srcNetwork], remoteContract: tokenDeploymentNamePerNetwork[targetNetwork] });
            }
        }
    }
}