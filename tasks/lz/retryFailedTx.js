const { BigNumber } = require("ethers");
const { createClient, MessageStatus } = require("@layerzerolabs/scan-client");
const { tokenDeploymentNamePerNetwork } = require("../utils/lz");

module.exports = async function (taskArgs, hre) {
    const { changeNetwork, getContract, getContractAt, getNetworkConfigByLzChainId } = hre;
    const client = createClient('mainnet');

    // Get a list of messages by transaction hash
    const { messages } = await client.getMessagesBySrcTxHash(
        taskArgs.tx
    );

    if (messages.length === 0) {
        console.log(`tx ${taskArgs.tx} not found on layerzeroscan`);
        process.exit(1);
    }
    const message = messages[0];
    console.log(message);
    const status = message.status;
    const srcTxError = message.srcTxError;
    const dstTxError = message.dstTxError;

    console.log(`Found tx on layerzeroscan with status ${message.status}...`);

    if (status == MessageStatus.INFLIGHT || status == MessageStatus.DELIVERED || status == MessageStatus.FAILED) {
        console.log(`Nothing to do with status ${status}`);
        process.exit(1);
    }

    // determine if we need to retry from the source or destination chain
    let tx;
    let networkConfig;

    if (srcTxError) {
        networkConfig = getNetworkConfigByLzChainId(message.srcChainId);
        tx = message.srcTxHash;
    } else if (dstTxError) {
        networkConfig = getNetworkConfigByLzChainId(message.dstChainId);
        tx = message.dstTxHash;
    }
    const network = networkConfig.name;

    changeNetwork(network);
    const localChainId = networkConfig.chainId;
    const localContractInstance = await getContract(tokenDeploymentNamePerNetwork[network], localChainId);

    console.log(`⏳ Checking if message can be retried for tx ${tx} on ${network}...`);
    const config = require(`../../config/${network}.json`);

    let endpoint = config.addresses.find(a => a.key === "LZendpoint");
    if (!endpoint) {
        console.log(`No LZendpoint address found for ${network}`);
        process.exit(1);
    }

    endpoint = endpoint.value;

    let fromLzChainId;
    let srcAddress;
    let nonce;
    let payload;
    let type;

    try {
        const receipt = await ethers.provider.getTransactionReceipt(tx);
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
            console.error(`Cannot retrieve failed payload with tx hash ${tx} on ${network}`);
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
        console.error(`Cannot retrieve failed message/stored payload with tx hash ${tx} on ${network}. Or, it has already been successfully retrieved.`);
        //console.log(e);
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