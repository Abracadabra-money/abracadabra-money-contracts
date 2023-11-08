const { BigNumber } = require("ethers");
const { feeHandlerDeployments } = require("../utils/lz");

module.exports = async function (taskArgs, hre) {
    const { changeNetwork, getDeployment, getChainIdByNetworkName, getContractAt } = hre;

    let networks = Object.keys(hre.config.networks);

    if (taskArgs.networks) {
        networks = taskArgs.networks;
    }

    for (const network of networks) {
        await changeNetwork(network);
        const chainId = getChainIdByNetworkName(network);
        const deployment = await getDeployment(feeHandlerDeployments[network], chainId);
        const signer = (await hre.ethers.getSigners())[0];
        const feeHandler = await ethers.getContractAt([{
            "inputs": [],
            "name": "withdrawFees",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        }], deployment.address, signer);

        process.stdout.write(`[${network}] ⏳ Withdrawing Fee...`);
        
        // only withdraw when there's ETH in the contract
        const balance = await ethers.provider.getBalance(deployment.address);
        if (balance.isZero()) {
            console.log("Nothing to withdraw");
            continue;
        }

        const tx = await (await feeHandler.withdrawFees()).wait();
        console.log(`${tx.transactionHash}`);
    }
}
