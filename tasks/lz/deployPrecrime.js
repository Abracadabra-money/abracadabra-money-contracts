const shell = require('shelljs');
const { utils } = require("ethers");
const {
    tokenDeploymentNamePerNetwork: _tokenDeploymentNamePerNetwork,
    spellTokenDeploymentNamePerNetwork: _spellTokenDeploymentNamePerNetwork,
    ownerPerNetwork,
    precrimeDeploymentNamePerNetwork: _precrimeDeploymentNamePerNetwork,
    spellPrecrimeDeploymentNamePerNetwork: _spellPrecrimeDeploymentNamePerNetwork
} = require('../utils/lz');

module.exports = async function (taskArgs, hre) {
    const { changeNetwork, getLzChainIdByNetworkName, getContract, getDeployer } = hre;

    let script;
    let precrimeDeploymentNamePerNetwork;
    let tokenDeploymentNamePerNetwork;
    const token = taskArgs.token;

    if (token == "mim") {
        script = "PreCrime";
        tokenDeploymentNamePerNetwork = _tokenDeploymentNamePerNetwork;
        precrimeDeploymentNamePerNetwork = _precrimeDeploymentNamePerNetwork;
    } else if (token == "spell") {
        script = "SpellPreCrime";
        tokenDeploymentNamePerNetwork = _spellTokenDeploymentNamePerNetwork;
        precrimeDeploymentNamePerNetwork = _spellPrecrimeDeploymentNamePerNetwork;
    } else {
        console.error("Invalid token. Please use 'mim' or 'spell'");
        process.exit(1);
    }

    //const networks = ["mainnet", "avalanche", "polygon", "fantom", "optimism", "arbitrum", "moonriver", "bsc", "kava", "base", "linea"];
    const networks = ["blast"];


    await shell.exec("yarn build");
    await hre.run("forge-deploy-multichain", { script, broadcast: taskArgs.broadcast, verify: taskArgs.verify, networks, noConfirm: taskArgs.noConfirm, resume: taskArgs.resume });

    const deployer = await getDeployer();

    // Only run the following if we are broadcasting
    if (taskArgs.broadcast) {
        for (const srcNetwork of networks) {
            changeNetwork(srcNetwork);

            // get local contract
            const localContractInstance = await getContract(precrimeDeploymentNamePerNetwork[srcNetwork], hre.network.config.chainId)
            let remoteChainIDs = [];
            let remotePrecrimeAddresses = [];

            for (const targetNetwork of Object.keys(precrimeDeploymentNamePerNetwork)) {
                if (targetNetwork === srcNetwork) continue;

                console.log(`[${srcNetwork}] Adding Precrime for ${precrimeDeploymentNamePerNetwork[targetNetwork]}`);
                const remoteChainId = hre.getNetworkConfigByName(targetNetwork).chainId;
                const remoteContractInstance = await getContract(precrimeDeploymentNamePerNetwork[targetNetwork], remoteChainId);

                const bytes32address = utils.defaultAbiCoder.encode(["address"], [remoteContractInstance.address])
                remoteChainIDs.push(getLzChainIdByNetworkName(targetNetwork));
                remotePrecrimeAddresses.push(bytes32address)
            }

            try {
                let tx = await (await localContractInstance.setRemotePrecrimeAddresses(remoteChainIDs, remotePrecrimeAddresses)).wait()
                console.log(`✅ [${hre.network.name}] setRemotePrecrimeAddresses`)
                console.log(` tx: ${tx.transactionHash}`)
            } catch (e) {
                console.log(`❌ [${hre.network.name}] setRemotePrecrimeAddresses`)
            }

            const token = await getContract(tokenDeploymentNamePerNetwork[srcNetwork], hre.network.config.chainId);
            console.log(`Setting precrime address to ${localContractInstance.address}...`);

            if (await token.precrime() != localContractInstance.address) {
                const owner = await token.owner();
                if (owner == deployer.address) {
                    try {
                        let tx = await (await token.setPrecrime(localContractInstance.address)).wait()
                        console.log(`✅ [${hre.network.name}] setPrecrime`)
                        console.log(` tx: ${tx.transactionHash}`)
                    } catch (e) {
                        console.log(`❌ [${hre.network.name}] setPrecrime`)
                    }
                } else {
                    console.log(`owner is ${owner}`);
                    console.log(`deployer is ${deployer.address}`);
                    console.log(`[${hre.network.name}] Skipping setPrecrime as token owner is not deployer. Use lzGnosisConfigure task to schedule a gnosis transaction to setPrecrime`)
                }
            } else {
                console.log(`[${hre.network.name}] already set to ${localContractInstance.address}`)
            }

            const owner = ownerPerNetwork[srcNetwork];

            console.log(`[${hre.network.name}] Changing owner of ${localContractInstance.address} to ${owner}...`);

            if (await localContractInstance.owner() !== owner) {
                try {
                    const tx = await localContractInstance.transferOwnership(owner);
                    console.log(`[${hre.network.name}] Transaction: ${tx.hash}`);
                    await tx.wait();
                } catch {
                    console.log(`[${hre.network.name}] Failed to change owner of ${localContractInstance.address} to ${owner}...`);
                }
            }
            else {
                console.log(`[${hre.network.name}] Owner is already ${owner}...`);
            }

        }
    }
}