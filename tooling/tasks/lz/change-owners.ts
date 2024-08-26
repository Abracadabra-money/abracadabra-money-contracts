import {ethers} from "ethers";
import {
    mimTokenDeploymentNamePerNetwork,
    minterDeploymentNamePerNetwork,
    ownerPerNetwork,
    spellTokenDeploymentNamePerNetwork,
} from "../utils/lz";
import type {TaskArgs, TaskFunction, TaskMeta} from "../../types";
import type {Tooling} from "../../tooling";

export const meta: TaskMeta = {
    name: "lz/change-owners",
    description: "Change the owner of token and minter contracts across multiple networks",
    options: {
        token: {
            type: "string",
            description: "Token to deploy",
            required: true,
            choices: ["mim", "spell"],
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const token = taskArgs.token;
    const networks = tooling.getAllNetworks();
    let tokenDeploymentNamePerNetwork: {[key: string]: string} = {};

    if (token === "mim") {
        tokenDeploymentNamePerNetwork = mimTokenDeploymentNamePerNetwork;
    } else if (token === "spell") {
        tokenDeploymentNamePerNetwork = spellTokenDeploymentNamePerNetwork;
    }

    for (const network of networks) {
        const config = tooling.getNetworkConfigByName(network);
        if (config.extra?.mimLzUnsupported || !tokenDeploymentNamePerNetwork[network]) {
            continue;
        }

        const owner = ownerPerNetwork[network];
        const chainId = tooling.getChainIdByName(network);
        const tokenContract = await tooling.getContract(tokenDeploymentNamePerNetwork[network], chainId);

        console.log(`[${network}] Changing owner of ${tokenContract.address} to ${owner}...`);

        if ((await tokenContract.owner()) !== owner) {
            const tx = await tokenContract.transferOwnership(owner);
            console.log(`[${network}] Transaction: ${tx.hash}`);
            await tx.wait();
        } else {
            console.log(`[${network}] Owner is already ${owner}...`);
        }

        if (token === "mim" && minterDeploymentNamePerNetwork[network]) {
            const minterContract = await tooling.getContract(minterDeploymentNamePerNetwork[network], chainId);

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
