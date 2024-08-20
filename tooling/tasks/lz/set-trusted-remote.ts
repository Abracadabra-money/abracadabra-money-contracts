import type { Tooling } from '../../tooling';
import type { TaskArgs, TaskFunction, TaskMeta } from '../../types';
import { ethers } from 'ethers';

// usage example:
// bun task set-trusted-remote --network optimism --target-network fantom --local-contract Optimism_IndirectOFTV2 --remote-contract Fantom_IndirectOFTV2
export const meta: TaskMeta = {
    name: 'lz/set-trusted-remote',
    description: 'Set trusted remote for LayerZero contract',
    options: {
        network: {
            type: 'string',
            description: 'The network to use',
            required: true,
        },
        targetNetwork: {
            type: 'string',
            description: 'The target network to set the trusted remote for',
            required: true,
        },
        contract: {
            type: 'string',
            description: 'The contract to set the trusted remote for',
            required: false,
        },
        localContract: {
            type: 'string',
            description: 'The local contract to set the trusted remote for',
            required: false,
        },
        remoteContract: {
            type: 'string',
            description: 'The remote contract to set the trusted remote for',
            required: false,
        },
        noSubmit: {
            type: 'boolean',
            description: 'If set, will not submit the transaction',
            required: false,
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    if (taskArgs.network) {
        await tooling.changeNetwork(taskArgs.network as string);
    }

    let localContract: string | undefined;
    let remoteContract: string | undefined;
    const noSubmit = taskArgs.noSubmit || false;

    if (taskArgs.contract) {
        localContract = taskArgs.contract as string;
        remoteContract = taskArgs.contract as string;
    } else {
        localContract = taskArgs.localContract as string;
        remoteContract = taskArgs.remoteContract as string;
    }

    if (!localContract || !remoteContract) {
        console.log('Must pass in contract name OR pass in both --local-contract name and --remote-contract name');
        return;
    }

    // get local chain id
    const localChainId = tooling.network.config.chainId;

    // get remote chain id
    const remoteChainId = tooling.getNetworkConfigByName(taskArgs.targetNetwork as string).chainId;

    // get remote layerzero chain id
    const remoteLzChainId = tooling.getLzChainIdByName(taskArgs.targetNetwork as string);

    // get local contract
    const localContractInstance = await tooling.getContract(localContract, localChainId);

    // get deployed remote contract address
    const remoteContractInstance = await tooling.getContract(remoteContract, remoteChainId);

    // concat remote and local address
    let remoteAndLocal = ethers.utils.solidityPack(
        ['address', 'address'],
        [remoteContractInstance.address, localContractInstance.address]
    );

    // check if pathway is already set
    const isTrustedRemoteSet = await localContractInstance.isTrustedRemote(remoteLzChainId, remoteAndLocal);

    if (!isTrustedRemoteSet) {
        try {
            console.log(`✅ [${tooling.network.name}] setTrustedRemote(${remoteLzChainId}, ${remoteAndLocal})`);

            if (noSubmit) {
                let tx = await localContractInstance.populateTransaction.setTrustedRemote(remoteLzChainId, remoteAndLocal);

                console.log('Skipping tx submission.');
                console.log();
                console.log('=== contract ===');
                console.log(localContractInstance.address);
                console.log();
                console.log('=== hex data ===');
                console.log(tx.data);
                console.log();
                process.exit(0);
            }

            let tx = await (await localContractInstance.setTrustedRemote(remoteLzChainId, remoteAndLocal)).wait();
            console.log(` tx: ${tx.transactionHash}`);
        } catch (e) {
            console.log(`❌ [${tooling.network.name}] setTrustedRemote(${remoteLzChainId}, ${remoteAndLocal})`);
        }
    } else {
        console.log('*source already set*');
    }
};
