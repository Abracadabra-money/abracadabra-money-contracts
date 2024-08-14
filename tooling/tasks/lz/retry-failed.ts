import { ethers } from 'ethers';
import { createClient, MessageStatus } from '@layerzerolabs/scan-client';
import { tokenDeploymentNamePerNetwork } from '../utils/lz';
import type { NetworkConfigWithName, TaskArgs, TaskFunction, TaskMeta, Tooling } from '../../types';

export const meta: TaskMeta = {
    name: 'lz/retry-failed',
    description: 'Retry LayerZero messages',
    options: {
        tx: {
            type: 'string',
            description: 'Transaction hash to retry',
            required: true,
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const client = createClient('mainnet');

    const { messages } = await client.getMessagesBySrcTxHash(taskArgs.tx as string);

    if (messages.length === 0) {
        console.log(`tx ${taskArgs.tx} not found on layerzeroscan`);
        process.exit(1);
    }
    const message = messages[0];
    console.log(message);
    const status = message.status;
    const dstTxError = message.dstTxError;

    console.log(`Found tx on layerzeroscan with status ${message.status}...`);

    if (status === MessageStatus.INFLIGHT || status === MessageStatus.DELIVERED || status === MessageStatus.FAILED) {
        console.log(`Nothing to do with status ${status}`);
        process.exit(1);
    }

    let tx;
    let networkConfig: NetworkConfigWithName;

    if (dstTxError) {
        networkConfig = tooling.getNetworkConfigByLzChainId(message.dstChainId);
        tx = message.dstTxHash;
    } else {
        console.error(`Cannot retrieve failed message with tx hash ${taskArgs.tx} on layerzeroscan`);
        process.exit(1);
    }

    const network = networkConfig.name;

    await tooling.changeNetwork(network);
    const localChainId = networkConfig.chainId;
    const localContractInstance = await tooling.getContract(tokenDeploymentNamePerNetwork[network], localChainId);

    console.log(`⏳ Checking if message can be retried for tx ${tx} on ${network}...`);
    const endpoint = tooling.getAddressByLabel(network, 'LZendpoint') as `0x${string}`;

    let fromLzChainId;
    let srcAddress;
    let nonce;
    let payload;
    let type;

    try {
        const receipt = await tooling.getProvider().getTransactionReceipt(tx as string);
        const abi = [
            'event MessageFailed(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload, bytes _reason)',
            'event PayloadStored(uint16 _srcChainId, bytes _srcAddress, address dstAddress, uint64 _nonce, bytes _payload, bytes reason)',
        ];

        const iface = new ethers.utils.Interface(abi);
        const logs = receipt.logs.map((log) => {
            try {
                return iface.parseLog(log);
            } catch (e) {
                return null;
            }
        });

        let event = logs.find((log) => log && (log.name === 'MessageFailed' || log.name === 'PayloadStored'));
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
    } catch (e) {
        console.error(`Cannot retrieve failed message/stored payload with tx hash ${tx} on ${network}. Or, it has already been successfully retrieved.`);
        process.exit(1);
    }

    switch (type) {
        case 'PayloadStored':
            console.log(`⏳ Retrying message from endpoint...`);
            const endpointContract = await tooling.getContractAt('ILzEndpoint', endpoint);

            tx = await (
                await endpointContract.retryPayload(
                    fromLzChainId,
                    srcAddress,
                    payload,
                    { value: 0 }
                )
            ).wait();
            break;
        case 'MessageFailed':
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
};