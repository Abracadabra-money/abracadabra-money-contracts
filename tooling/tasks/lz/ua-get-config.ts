import { tokenDeploymentNamePerNetwork, spellTokenDeploymentNamePerNetwork, getApplicationConfig } from '../utils/lz';
import type { TaskArgs, TaskFunction, TaskMeta } from '../../types';
import type { ethers } from 'ethers';
import type { Tooling } from '../../tooling';

export const meta: TaskMeta = {
    name: 'lz/ua-get-config',
    description: 'Check LayerZero configuration for a specific token',
    options: {
        token: {
            type: 'string',
            description: 'Token to check configuration for',
            required: true,
            choices: ['mim', 'spell'],
        },
        from: {
            type: 'string',
            description: 'Source network',
            required: true,
        },
        to: {
            type: 'string',
            description: 'Target networks (comma separated or "all")',
            required: true,
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    let deploymentNamePerNetwork: any;
    const token = taskArgs.token as string;

    if (token === 'mim') {
        deploymentNamePerNetwork = tokenDeploymentNamePerNetwork;
    } else if (token === 'spell') {
        deploymentNamePerNetwork = spellTokenDeploymentNamePerNetwork;
    }

    const network = taskArgs.from as string;
    tooling.changeNetwork(network);
    
    let toNetworks = (taskArgs.to as string).split(',');

    if (toNetworks.length === 1 && toNetworks[0] === 'all') {
        toNetworks = tooling.getAllNetworksLzMimSupported();
    }

    const localChainId = tooling.getChainIdByName(network);
    const oft = await tooling.getContract(deploymentNamePerNetwork[network], localChainId);

    if (!oft) {
        console.error(`Deployment information isn't found for ${network}`);
        return;
    }

    const oftAddress = oft.address as `0x${string}`;
    const endpointAddress = tooling.getAddressByLabel(network, 'LZendpoint') as `0x${string}`;
    const endpoint = await tooling.getContractAt('ILzEndpoint', endpointAddress);

    const appConfig = await endpoint.uaConfigLookup(oftAddress);
    const sendVersion = appConfig.sendVersion;
    const receiveVersion = appConfig.receiveVersion;
    const sendLibraryAddress = sendVersion === 0 ? await endpoint.defaultSendLibrary() : appConfig.sendLibrary;
    const sendLibrary = await tooling.getContractAt('ILzUltraLightNodeV2', sendLibraryAddress);

    let receiveLibrary;
    if (sendVersion !== receiveVersion) {
        const receiveLibraryAddress = receiveVersion === 0 ? await endpoint.defaultReceiveLibraryAddress() : appConfig.receiveLibraryAddress;
        receiveLibrary = await tooling.getContractAt('ILzUltraLightNodeV2', receiveLibraryAddress);
    }

    const remoteConfigs = [];
    for (let toNetwork of toNetworks) {
        if (network === toNetwork) {
            continue;
        }

        const config = await getApplicationConfig(tooling, toNetwork, sendLibrary, receiveLibrary as ethers.Contract, oftAddress);
        remoteConfigs.push(config);
    }

    console.log('Network            ', network);
    console.log('Application address', oftAddress);
    console.log('Send version       ', sendVersion);
    console.log('Receive version    ', receiveVersion);
    console.table(remoteConfigs);
};
