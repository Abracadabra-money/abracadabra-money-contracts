const shell = require('shelljs');

module.exports = async function (taskArgs, hre) {
    const { getContract, getChainIdByNetworkName } = hre;

    const networks = ["optimism", "arbitrum", "moonriver", "avalanche", "mainnet", "bsc", "polygon", "fantom", "kava", "base"];

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
    };

    const minterDeploymentNamePerNetwork = {
        "mainnet": undefined,
        "bsc": "BSC_ElevatedMinterBurner",
        "polygon": "Polygon_ElevatedMinterBurner",
        "fantom": "Fantom_ElevatedMinterBurner",
        "optimism": "Optimism_ElevatedMinterBurner",
        "arbitrum": "Arbitrum_ElevatedMinterBurner",
        "avalanche": "Avalanche_ElevatedMinterBurner",
        "moonriver": "Moonriver_ElevatedMinterBurner",
        "kava": undefined,
        "base": undefined,
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
        "kava": "0x1261894F79E6CF21bF7E586Af7905Ec173C8805b",
        "base": "0xF657dE126f9D7666b5FFE4756CcD9EB393d86a92", // should be changed later to larger gnosis safe
    };


    for (const network of networks) {
        const owner = ownerPerNetwork[network];
        const chainId = getChainIdByNetworkName(network);
        const tokenContract = await getContract(tokenDeploymentNamePerNetwork[network], chainId);
        const minterContract = minterDeploymentNamePerNetwork[network] ? await getContract(minterDeploymentNamePerNetwork[network], chainId) : undefined;

        console.log(`[${network}] Changing owner of ${tokenContract.address} to ${owner}...`);

        if (await tokenContract.owner() !== owner) {
            const tx = await tokenContract.transferOwnership(owner);
            console.log(`[${network}] Transaction: ${tx.hash}`);
            await tx.wait();
        }
        else {
            console.log(`[${network}] Owner is already ${owner}...`);
        }

        if (minterContract) {
            console.log(`[${network}] Changing owner of ${minterContract.address} to ${owner}...`);

            if (await minterContract.owner() !== owner) {
                const tx = await minterContract.transferOwnership(owner, true, false);
                console.log(`[${network}] Transaction: ${tx.hash}`);
                await tx.wait();
            } else {
                console.log(`[${network}] Owner is already ${owner}...`);
            }
        }
    }
}