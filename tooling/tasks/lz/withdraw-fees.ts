import type {ContractInterface} from "ethers";
import type {TaskArgs, TaskFunction, TaskMeta} from "../../types";
import {mimFeeHandlerDeployments, spellFeeHandlerDeployments} from "../utils/lz";
import type {Tooling} from "../../tooling";

export const meta: TaskMeta = {
    name: "lz/oft:withdraw-fees",
    description: "Withdraw fees from fee handlers on multiple networks",
    options: {
        token: {
            type: "string",
            description: "Token to deploy",
            required: true,
            choices: ["mim", "spell"],
        },
    },
    positionals: {
        name: "networks",
        description: "Networks to withdraw fees from",
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const token = taskArgs.token;
    let networks = Object.keys(tooling.config.networks);
    let deploymentNamePerNetwork: {[key: string]: string} = {};

    if (taskArgs.networks) {
        networks = taskArgs.networks as string[];
    }

    if (token === "mim") {
        deploymentNamePerNetwork = mimFeeHandlerDeployments;
    } else if (token === "spell") {
        deploymentNamePerNetwork = spellFeeHandlerDeployments;
    }

    for (const network of networks) {
        const abi = [
            {
                inputs: [],
                name: "withdrawFees",
                outputs: [],
                stateMutability: "nonpayable",
                type: "function",
            },
        ] as ContractInterface;

        await tooling.changeNetwork(network);
        const chainId = tooling.getChainIdByName(network);
        const deployment = await tooling.getDeployment(deploymentNamePerNetwork[network], chainId);
        const feeHandler = await tooling.getContractAt(abi, deployment.address);

        process.stdout.write(`[${network}] ⏳ Withdrawing Fee...`);

        // only withdraw when there's ETH in the contract
        const balance = await tooling.getProvider().getBalance(deployment.address);
        if (balance.isZero()) {
            console.log("Nothing to withdraw");
            continue;
        }

        const tx = await (await feeHandler.withdrawFees()).wait();
        console.log(`${tx.transactionHash}`);
    }
};
