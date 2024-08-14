import { BigNumber } from 'ethers';
import type { TaskArgs, TaskFunction, TaskMeta, Tooling } from '../../types';

export const meta: TaskMeta = {
    name: 'lz/set-min-dst-gas',
    description: 'Set minimum destination gas for a OFTV2 contract',
    options: {
        network: {
            type: 'string',
            description: 'The network to use',
            required: true,
        },
        contract: {
            type: 'string',
            description: 'The contract to set minimum destination gas for',
            required: true,
        },
        targetNetwork: {
            type: 'string',
            description: 'The target network to set the minimum gas for',
            required: true,
        },
        packetType: {
            type: 'string',
            description: 'The packet type to set the minimum gas for',
            choices: ['0', '1'],
            required: true,
        },
        minGas: {
            type: 'string',
            description: 'The minimum gas value to set',
            required: true,
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    await tooling.changeNetwork(taskArgs.network as string);

    const localChainId = tooling.getChainIdByNetworkName(taskArgs.network as string);
    const contract = await tooling.getContract(taskArgs.contract as string, localChainId);
    const dstChainId = tooling.getLzChainIdByNetworkName(taskArgs.targetNetwork as string);

    const currentMinGas = await contract.minDstGasLookup(dstChainId, taskArgs.packetType as string);
    const minGas = BigNumber.from(taskArgs.minGas);

    if (!currentMinGas.eq(minGas)) {
        const tx = await contract.setMinDstGas(dstChainId, taskArgs.packetType as string, minGas);
        console.log(`[${tooling.network.name}] setMinDstGas tx hash ${tx.hash}`);
        await tx.wait();
    } else {
        console.log(`[${tooling.network.name}] setMinDstGas already set to ${taskArgs.minGas}`);
    }
};
