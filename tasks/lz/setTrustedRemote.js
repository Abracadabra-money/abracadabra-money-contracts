const CHAIN_ID = require("./chainIds.json")

module.exports = async function (taskArgs, hre) {
    const { foundryDeployments, changeNetwork } = hre;
    changeNetwork(taskArgs.network);

    let localContract, remoteContract;

    if (taskArgs.contract) {
        localContract = taskArgs.contract;
        remoteContract = taskArgs.contract;
    } else {
        localContract = taskArgs.localContract;
        remoteContract = taskArgs.remoteContract;
    }

    if (!localContract || !remoteContract) {
        console.log("Must pass in contract name OR pass in both localContract name and remoteContract name")
        return
    }

    // get local chain id
    const localChainId = hre.network.config.chainId;

    // get remote chain id
    const remoteChainId = hre.getNetworkConfigByName(taskArgs.targetNetwork).chainId;

    // get remote layerzero chain id
    const remoteLzChainId = CHAIN_ID[taskArgs.targetNetwork];

    // get local contract
    const localContractInstance = await foundryDeployments.getContract(localContract, localChainId)

    // get deployed remote contract address
    const remoteContractInstance = await foundryDeployments.getContract(remoteContract, remoteChainId);

    // concat remote and local address
    let remoteAndLocal = hre.ethers.utils.solidityPack(
        ['address', 'address'],
        [remoteContractInstance.address, localContractInstance.address]
    )

    // check if pathway is already set
    const isTrustedRemoteSet = await localContractInstance.isTrustedRemote(remoteLzChainId, remoteAndLocal);

    if (!isTrustedRemoteSet) {
        try {
            let tx = await (await localContractInstance.setTrustedRemote(remoteLzChainId, remoteAndLocal)).wait()
            console.log(`✅ [${hre.network.name}] setTrustedRemote(${remoteLzChainId}, ${remoteAndLocal})`)
            console.log(` tx: ${tx.transactionHash}`)
        } catch (e) {
            console.log(`❌ [${hre.network.name}] setTrustedRemote(${remoteLzChainId}, ${remoteAndLocal})`)
        }
    } else {
        console.log("*source already set*")
    }
}
