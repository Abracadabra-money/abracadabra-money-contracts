const { BigNumber } = require("ethers");

module.exports = async function (taskArgs, hre) {
    const { foundryDeployments, changeNetwork, getChainIdByNetworkName } = hre;

    taskArgs.network = hre.network.name;

    if (!taskArgs.network) {
        console.error("Missing network parameter");
        process.exit(1);
    }

    changeNetwork(taskArgs.network);

    const tokenDeploymentNamePerNetwork = {
        "mainnet": "Mainnet_ProxyOFTV2",
        "bsc": "BSC_IndirectOFTV2",
        "polygon": "Polygon_IndirectOFTV2",
        "fantom": "Fantom_IndirectOFTV2",
        "optimism": "Optimism_IndirectOFTV2",
        "arbitrum": "Arbitrum_IndirectOFTV2",
        "avalanche": "Avalanche_IndirectOFTV2",
        "moonriver": "Moonriver_IndirectOFTV2",
    };

    const localChainId = getChainIdByNetworkName(taskArgs.network);
    const localContractInstance = await foundryDeployments.getContract(tokenDeploymentNamePerNetwork[taskArgs.network], localChainId);

    console.log(`⏳ Checking if message can be retried for tx ${taskArgs.tx} on ${taskArgs.network}...`);
    let fromLzChainId;
    let srcAddress;
    let nonce;
    let payload;

    try {
        const receipt = await ethers.provider.getTransactionReceipt(taskArgs.tx);
        const abi = ["event MessageFailed(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload, bytes _reason)"];
        const iface = new ethers.utils.Interface(abi);
        const logs = receipt.logs.map((log) => {
            try {
                return iface.parseLog(log);
            } catch (e) {
                return null;
            }
        });
        const event = logs.find((log) => log && log.name === "MessageFailed");
        if (!event) {
            console.error(`Cannot retrieve failed message with tx hash ${taskArgs.tx} on ${taskArgs.network}`);
            process.exit(1);
        }
        const { args } = event;
        fromLzChainId = args._srcChainId;
        srcAddress = args._srcAddress;
        nonce = args._nonce;
        payload = args._payload;
        console.log(`fromLzChainId: ${fromLzChainId}`);
        console.log(`srcAddress: ${srcAddress}`);
        console.log(`nonce: ${nonce}`);
        console.log(`payload: ${payload}`);

    }
    catch (e) {
        console.error(`Cannot retrieve failed message with tx hash ${taskArgs.tx} on ${taskArgs.network}. Or, it has already been successfully retried.`);
        process.exit(1);
    }

    console.log(`⏳ Retrying message...`);
    tx = await (
        await localContractInstance.retryMessage(
            fromLzChainId,
            srcAddress,
            nonce,
            payload,
            { value: 0 }
        )
    ).wait();
    console.log(`✅ Sent retry message tx: ${tx.transactionHash}`);
}