import type {TaskArgs, TaskArgValue, TaskFunction, TaskMeta} from "../../types";
import type {Tooling} from "../../tooling";
import {lz} from "../utils/lz";

export const meta: TaskMeta = {
    name: "lz/change-owners",
    description: "Change the owner of token and minter contracts across multiple networks",
    options: {
        token: {
            type: "string",
            description: "Token to deploy",
            required: true,
            choices: ["mim", "spell"],
            transform: (value: TaskArgValue) => (value as string).toUpperCase(),
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const tokenName = taskArgs.token as string;
    const networks = lz.getSupportedNetworks(tokenName);

    for (const network of networks) {
        const config = lz.getDeployementConfig(tooling, tokenName, network);

        const owner = config.owner;
        const chainId = tooling.getChainIdByName(network);
        const tokenContract = await tooling.getContract(config.oft, chainId);

        console.log(`[${network}] Changing owner of ${tokenContract.address} to ${owner}...`);

        if ((await tokenContract.owner()) !== owner) {
            const tx = await tokenContract.transferOwnership(owner);
            console.log(`[${network}] Transaction: ${tx.hash}`);
            await tx.wait();
        } else {
            console.log(`[${network}] Owner is already ${owner}...`);
        }

        if (config.minterBurner) {
            const minterContract = await tooling.getContract(config.minterBurner, chainId);

            console.log(`[${network}] Changing owner of ${minterContract.address} to ${owner}...`);

            if ((await minterContract.owner()) !== owner) {
                const tx = await minterContract.transferOwnership(owner, true, false);
                console.log(`[${network}] Transaction: ${tx.hash}`);
                await tx.wait();
            } else {
                console.log(`[${network}] Owner is already ${owner}...`);
            }
        }
    }
};
