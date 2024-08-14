import type { TaskArgs, TaskFunction, TaskMeta, Tooling } from '../../types';

export const meta: TaskMeta = {
    name: 'core/blocknumbers',
    description: 'Check the latest blocks for all networks'
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const { config } = tooling;

    const networks = Object.keys(config.networks).map(network => ({
        name: network,
        chainId: config.networks[network].chainId
    }));
    
    const chainIdEnum = Object.keys(config.networks).reduce((acc, network) => {
        const capitalizedNetwork = network.charAt(0).toUpperCase() + network.slice(1);
        return { ...acc, [config.networks[network].chainId]: capitalizedNetwork };
    }, {}) as { [chainId: number]: string };

    const latestBlocks: { [chainId: number]: number } = {};

    await Promise.all(networks.map(async (network) => {
        console.log(`Querying ${network.name}...`);
        tooling.changeNetwork(network.name);
        const latestBlock = await tooling.getProvider().getBlockNumber();
        latestBlocks[network.chainId] = latestBlock;
    }));

    await Promise.all(networks.map(async (network) => {
        console.log(`${network.name}: ${latestBlocks[network.chainId]}`);
    }));

    console.log('\nCode:\n----');
    await Promise.all(networks.map(async (network) => {
        console.log(`fork(ChainId.${chainIdEnum[network.chainId]}, ${latestBlocks[network.chainId]});`);
    }));
};