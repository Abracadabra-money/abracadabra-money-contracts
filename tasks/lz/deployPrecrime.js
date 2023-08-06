const shell = require('shelljs');
const { utils } = require("ethers")

module.exports = async function (taskArgs, hre) {
    const { changeNetwork, getLzChainIdByNetworkName, getContract, getDeployer } = hre;
    //const networks = ["mainnet", "avalanche", "polygon", "fantom", "optimism", "arbitrum", "moonriver", "bsc", "kava", "base", "linea"];
    const networks = ["linea"];

    const deploymentNamePerNetwork = {
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
        "linea": "Linea_Precrime"
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

    const ownerPerNetwork = {
        "mainnet": "0x5f0DeE98360d8200b20812e174d139A1a633EDd2",
        "bsc": "0x9d9bC38bF4A128530EA45A7d27D0Ccb9C2EbFaf6",
        "polygon": "0x7d847c4A0151FC6e79C6042D8f5B811753f4F66e",
        "fantom": "0xb4ad8B57Bd6963912c80FCbb6Baea99988543c1c",
        "optimism": "0x4217AA01360846A849d2A89809d450D10248B513",
        "arbitrum": "0xf46BB6dDA9709C49EfB918201D97F6474EAc5Aea",
        "avalanche": "0xae64A325027C3C14Cf6abC7818aA3B9c07F5C799",
        "moonriver": "0xfc88aa661C44B4EdE197644ba971764AC59AFa62",
        "kava": "0x3A2761F421b7E3Fd18C1aD50c461b2DE2F77c367",
        "base": "0xF657dE126f9D7666b5FFE4756CcD9EB393d86a92",
        "linea": "0x1c063276CF810957cf0665903FAd20d008f4b404"
    };

    await shell.exec("yarn build");
    await hre.run("forge-deploy-multichain", { script: "PreCrime", broadcast: taskArgs.broadcast, verify: taskArgs.verify, networks, noConfirm: taskArgs.noConfirm, resume: taskArgs.resume });

    const deployer = await getDeployer();

    // Only run the following if we are broadcasting
    if (taskArgs.broadcast) {
        for (const srcNetwork of networks) {
            changeNetwork(srcNetwork);

            // get local contract
            const localContractInstance = await getContract(deploymentNamePerNetwork[srcNetwork], hre.network.config.chainId)
            let remoteChainIDs = [];
            let remotePrecrimeAddresses = [];

            for (const targetNetwork of Object.keys(deploymentNamePerNetwork)) {
                if (targetNetwork === srcNetwork) continue;
            
                console.log(`[${srcNetwork}] Adding Precrime for ${deploymentNamePerNetwork[targetNetwork]}`);
                const remoteChainId = hre.getNetworkConfigByName(targetNetwork).chainId;
                const remoteContractInstance = await getContract(deploymentNamePerNetwork[targetNetwork], remoteChainId);
            
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