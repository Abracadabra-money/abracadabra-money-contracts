const CHAIN_ID = require("../constants/chainIds.json")

module.exports = async function (taskArgs, hre) {
    const { foundryDeployments } = hre;

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
    const remoteChainId = CHAIN_ID[taskArgs.targetNetwork]

    // get local contract
    const localContractInstance = await foundryDeployments.get(localContract, localChainId)

    // get deployed remote contract address
    const remoteAddress = await foundryDeployments.get(remoteContract, remoteChainId);

    // concat remote and local address
    let remoteAndLocal = hre.ethers.utils.solidityPack(
        ['address', 'address'],
        [remoteAddress, localContractInstance.address]
    )

    // check if pathway is already set
    const isTrustedRemoteSet = await localContractInstance.isTrustedRemote(remoteChainId, remoteAndLocal);

    if (!isTrustedRemoteSet) {
        try {
            let tx = await (await localContractInstance.setTrustedRemote(remoteChainId, remoteAndLocal)).wait()
            console.log(`✅ [${hre.network.name}] setTrustedRemote(${remoteChainId}, ${remoteAndLocal})`)
            console.log(` tx: ${tx.transactionHash}`)
        } catch (e) {
            if (e.error.message.includes("The chainId + address is already trusted")) {
                console.log("*source already set*")
            } else {
                console.log(`❌ [${hre.network.name}] setTrustedRemote(${remoteChainId}, ${remoteAndLocal})`)
            }
        }
    } else {
        console.log("*source already set*")
    }
}
