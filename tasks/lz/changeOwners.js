const shell = require('shelljs');
const { tokenDeploymentNamePerNetwork, minterDeploymentNamePerNetwork, ownerPerNetwork } = require('../utils/lz');

module.exports = async function (taskArgs, hre) {
    const { getContract, getChainIdByNetworkName } = hre;

    const networks = ["optimism", "arbitrum", "moonriver", "avalanche", "mainnet", "bsc", "polygon", "fantom", "kava", "base"];

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