// usage exemple:
// yarn task lzSetTrustedRemote --local-contract Moonriver_IndirectOFTV2 --remote-contract Kava_IndirectOFTv2 --target-network kava --network moonriver --no-submit
module.exports = async function (taskArgs, hre) {
    const { getContract, changeNetwork, getLzChainIdByNetworkName } = hre;
    if (taskArgs.network) {
        changeNetwork(taskArgs.network);
    }

    let localContract, remoteContract;
    let noSubmit = taskArgs.noSubmit || false;

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
    const remoteLzChainId = getLzChainIdByNetworkName(taskArgs.targetNetwork);

    // get local contract
    const localContractInstance = await getContract(localContract, localChainId)

    // get deployed remote contract address
    const remoteContractInstance = await getContract(remoteContract, remoteChainId);

    // concat remote and local address
    let remoteAndLocal = hre.ethers.utils.solidityPack(
        ['address', 'address'],
        [remoteContractInstance.address, localContractInstance.address]
    )

    // check if pathway is already set
    const isTrustedRemoteSet = await localContractInstance.isTrustedRemote(remoteLzChainId, remoteAndLocal);

    if (!isTrustedRemoteSet) {
        try {
            console.log(`✅ [${hre.network.name}] setTrustedRemote(${remoteLzChainId}, ${remoteAndLocal})`)

            if (noSubmit) {
                let tx = await localContractInstance.populateTransaction.setTrustedRemote(remoteLzChainId, remoteAndLocal);

                console.log("Skipping tx submission.");
                console.log();
                console.log('=== contract ===');
                console.log(localContractInstance.address);
                console.log();
                console.log('=== hex data ===');
                console.log(tx.data);
                console.log();
                process.exit(0);
            }

            let tx = await (await localContractInstance.setTrustedRemote(remoteLzChainId, remoteAndLocal)).wait()
            console.log(` tx: ${tx.transactionHash}`)
        } catch (e) {
            console.log(`❌ [${hre.network.name}] setTrustedRemote(${remoteLzChainId}, ${remoteAndLocal})`)
        }
    } else {
        console.log("*source already set*")
    }
}
