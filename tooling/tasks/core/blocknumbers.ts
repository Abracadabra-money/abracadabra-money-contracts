import { CHAIN_NETWORK_NAME_PER_CHAIN_ID, type Tooling } from "../../tooling";
import {NetworkName, type TaskArgs, type TaskFunction, type TaskMeta} from "../../types";

export const meta: TaskMeta = {
    name: "core/blocknumbers",
    description: "Check the latest blocks for all networks",
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const {config} = tooling;

    const networks = Object.values(NetworkName).map((network) => ({
        name: network,
        chainId: config.networks[network as NetworkName].chainId,
    }));

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
            console.log(`fork(ChainId.${CHAIN_NETWORK_NAME_PER_CHAIN_ID[network.chainId]}, ${latestBlocks[network.chainId]});`);
        })
    );
};
