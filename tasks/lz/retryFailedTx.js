const { BigNumber } = require("ethers");

// When the transaction failed with MESSAGE_FAILED, tx should be the source chain tx hash,
// otherwise when it has failed with PAYLOAD_STORED, it should be the destination chain tx hash
module.exports = async function (taskArgs, hre) {
    const { foundryDeployments, changeNetwork, getChainIdByNetworkName, getContractAt } = hre;

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
        "kava": "Kava_IndirectOFTV2"
    };

    const config = require(`../../config/${taskArgs.network}.json`);

    let endpoint = config.addresses.find(a => a.key === "LZendpoint");
    if (!endpoint) {
        console.log(`No LZendpoint address found for ${network}`);
        process.exit(1);
    }

    endpoint = endpoint.value;

    const localChainId = getChainIdByNetworkName(taskArgs.network);
    const localContractInstance = await foundryDeployments.getContract(tokenDeploymentNamePerNetwork[taskArgs.network], localChainId);

    console.log(`⏳ Checking if message can be retried for tx ${taskArgs.tx} on ${taskArgs.network}...`);
    let fromLzChainId;
    let srcAddress;
    let nonce;
    let payload;
    let type;

    try {
        const receipt = await ethers.provider.getTransactionReceipt(taskArgs.tx);
        const abi = [
            "event MessageFailed(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload, bytes _reason)",
            "event PayloadStored(uint16 _srcChainId, bytes _srcAddress, address dstAddress, uint64 _nonce, bytes _payload, bytes reason)"
        ];

        const iface = new ethers.utils.Interface(abi);
        const logs = receipt.logs.map((log) => {
            try {
                return iface.parseLog(log);
            } catch (e) {
                return null;
            }
        });

        let event = logs.find((log) => log && (log.name === "MessageFailed" || log && log.name === "PayloadStored"));
        if (!event) {
            console.error(`Cannot retrieve failed payload with tx hash ${taskArgs.tx} on ${taskArgs.network}`);
            process.exit(1);
        }

        const { args } = event;
        fromLzChainId = args._srcChainId;
        srcAddress = args._srcAddress;
        nonce = args._nonce;
        payload = args._payload;
        type = event.name;

        console.log(`fromLzChainId: ${fromLzChainId}`);
        console.log(`srcAddress: ${srcAddress}`);
        console.log(`nonce: ${nonce}`);
        console.log(`payload: ${payload}`);

    }
    catch (e) {
        console.error(`Cannot retrieve failed message/stored payload with tx hash ${taskArgs.tx} on ${taskArgs.network}. Or, it has already been successfully retried.`);
        console.log(e);
        process.exit(1);
    }
    switch (type) {
        case "PayloadStored":
            console.log(`⏳ Retrying message from endpoint...`);
            const endpointContract = await getContractAt("ILzEndpoint", endpoint);

            tx = await (
                await endpointContract.retryPayload(
                    fromLzChainId,
                    srcAddress,
                    payload,
                    { value: 0 }
                )
            ).wait();
            break;
        case "MessageFailed":
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
            break;
    }

    console.log(`✅ Sent retry message tx: ${tx.transactionHash}`);
}