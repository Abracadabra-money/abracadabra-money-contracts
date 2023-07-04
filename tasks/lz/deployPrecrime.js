const shell = require('shelljs');
const CHAIN_ID = require("./chainIds.json")
const { utils } = require("ethers")

module.exports = async function (taskArgs, hre) {
    const { foundryDeployments, changeNetwork } = hre;
    const networks = ["mainnet", "avalanche", "polygon", "fantom", "optimism", "arbitrum", "moonriver", "bsc"];

    const deploymentNamePerNetwork = {
        "mainnet": "Mainnet_Precrime",
        "bsc": "BSC_Precrime",
        "polygon": "Polygon_Precrime",
        "fantom": "Fantom_Precrime",
        "optimism": "Optimism_Precrime",
        "arbitrum": "Arbitrum_Precrime",
        "avalanche": "Avalanche_Precrime",
        "moonriver": "Moonriver_Precrime",
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
    };

    await shell.exec("yarn build");
    await hre.run("forge-deploy-multichain", { script: "MIMLayerZero", broadcast: taskArgs.broadcast, verify: taskArgs.verify, networks, noConfirm: taskArgs.noConfirm, resume: taskArgs.resume });

    // Only run the following if we are broadcasting
    if (taskArgs.broadcast) {
        for (const srcNetwork of networks) {
            changeNetwork(srcNetwork);

            // get local contract
            const localContractInstance = await foundryDeployments.getContract(deploymentNamePerNetwork[srcNetwork], hre.network.config.chainId)
            let remoteChainIDs = [];
            let remotePrecrimeAddresses = [];

            for (const targetNetwork of networks) {
                if (targetNetwork === srcNetwork) continue;

                console.log(`[${srcNetwork}] Adding Precrime for ${deploymentNamePerNetwork[targetNetwork]}`);
                const remoteChainId = hre.getNetworkConfigByName(targetNetwork).chainId;
                const remoteContractInstance = await foundryDeployments.getContract(deploymentNamePerNetwork[targetNetwork], remoteChainId);

                const bytes32address = utils.defaultAbiCoder.encode(["address"], [remoteContractInstance.address])
                remoteChainIDs.push(CHAIN_ID[targetNetwork])
                remotePrecrimeAddresses.push(bytes32address)
            }

            try {
                let tx = await (await localContractInstance.setRemotePrecrimeAddresses(remoteChainIDs, remotePrecrimeAddresses)).wait()
                console.log(`✅ [${hre.network.name}] setRemotePrecrimeAddresses`)
                console.log(` tx: ${tx.transactionHash}`)
            } catch (e) {
                console.log(`❌ [${hre.network.name}] setRemotePrecrimeAddresses`)
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