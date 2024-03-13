const shell = require('shelljs');
const { tokenDeploymentNamePerNetwork, spellTokenDeploymentNamePerNetwork } = require('../utils/lz');

module.exports = async function (taskArgs, hre) {
    const token = taskArgs.token;
    let script;
    let deploymentNamePerNetwork;

    if (token == "mim") {
        script = "MIMLayerZero";
        deploymentNamePerNetwork = tokenDeploymentNamePerNetwork;
    } else if (token == "spell") {
        script = "SpellLayerZero";
        deploymentNamePerNetwork = spellTokenDeploymentNamePerNetwork;
    } else {
        console.error("Invalid token. Please use 'mim' or 'spell'");
        process.exit(1);
    }

    // indicate here, networks to deploy on and configure
    //const networks = ["mainnet", "avalanche", "polygon", "fantom", "optimism", "arbitrum", "moonriver", "bsc", "kava", "base", "linea"];
    const networks = ["blast"];

    await shell.exec("yarn build");
    await hre.run("forge-deploy-multichain", { script, broadcast: taskArgs.broadcast, verify: taskArgs.verify, networks, noConfirm: taskArgs.noConfirm, resume: taskArgs.resume });

    // comment this line and edit tokenDeploymentNamePerNetwork in tasks/utils/lz.js once the deployment is done
    // and execute this script again
    // process.exit(1);

    // Only run the following if we are broadcasting
    if (taskArgs.broadcast) {
        for (const srcNetwork of networks) {
            const minGas = 100_000;

            for (const targetNetwork of Object.keys(deploymentNamePerNetwork)) {
                if (targetNetwork === srcNetwork) continue;

                console.log(" -> ", targetNetwork);
                console.log(`[${srcNetwork}] PacketType 0 - Setting minDstGas for ${deploymentNamePerNetwork[srcNetwork]} to ${minGas} for ${deploymentNamePerNetwork[targetNetwork]}`);
                await hre.run("lzSetMinDstGas", { network: srcNetwork, targetNetwork, contract: deploymentNamePerNetwork[srcNetwork], packetType: "0", minGas: minGas.toString() });

                console.log(" -> ", targetNetwork);
                console.log(`[${srcNetwork}] PacketType 1 - Setting minDstGas for ${deploymentNamePerNetwork[srcNetwork]} to ${minGas} for ${deploymentNamePerNetwork[targetNetwork]}`);
                await hre.run("lzSetMinDstGas", { network: srcNetwork, targetNetwork, contract: deploymentNamePerNetwork[srcNetwork], packetType: "1", minGas: minGas.toString() });

                console.log(`[${srcNetwork}] Setting trusted remote for ${deploymentNamePerNetwork[srcNetwork]} to ${deploymentNamePerNetwork[targetNetwork]}`);
                await hre.run("lzSetTrustedRemote", { network: srcNetwork, targetNetwork, localContract: deploymentNamePerNetwork[srcNetwork], remoteContract: deploymentNamePerNetwork[targetNetwork] });
            }
        }
    }
}