import type { Tooling } from "../../tooling";
import type {TaskArgs, TaskFunction, TaskMeta} from "../../types";

export const meta: TaskMeta = {
    name: "core/blocknumbers",
    description: "Check the latest blocks for all networks",
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const {config} = tooling;

    const networks = Object.keys(config.networks).map((network) => ({
        name: network,
        chainId: config.networks[network].chainId,
    }));

    const chainIdEnum = Object.keys(config.networks).reduce((acc, networkName) => {
        return {...acc, [config.networks[networkName].chainId]: config.networks[networkName].enumName};
    }, {}) as {[chainId: number]: string};

    const latestBlocks: {[chainId: number]: number} = {};

    await Promise.all(
        networks.map(async (network) => {
            console.log(`Querying ${network.name}...`);
            tooling.changeNetwork(network.name);
            const latestBlock = await tooling.getProvider().getBlockNumber();
            latestBlocks[network.chainId] = latestBlock;
        })
    );

    await Promise.all(
        networks.map(async (network) => {
            console.log(`${network.name}: ${latestBlocks[network.chainId]}`);
        })
    );

    console.log("\nCode:\n----");
    await Promise.all(
        networks.map(async (network) => {
            console.log(`fork(ChainId.${chainIdEnum[network.chainId]}, ${latestBlocks[network.chainId]});`);
        })
    );
};
