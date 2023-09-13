const shell = require('shelljs');
const { tokenDeploymentNamePerNetwork } = require('../utils/lz');

module.exports = async function (taskArgs, hre) {
    // indicate here, networks to deploy on and configure
    //const networks = ["mainnet", "avalanche", "polygon", "fantom", "optimism", "arbitrum", "moonriver", "bsc", "kava", "base", "linea"];
    const networks = ["linea"];

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