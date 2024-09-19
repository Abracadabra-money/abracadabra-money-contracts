import type {ContractInterface} from "ethers";
import {NetworkName, type TaskArgs, type TaskArgValue, type TaskFunction, type TaskMeta} from "../../types";
import type {Tooling} from "../../tooling";
import {lz} from "../utils/lz";

export const meta: TaskMeta = {
    name: "lz/oft:withdraw-fees",
    description: "Withdraw fees from fee handlers on multiple networks",
    options: {
        token: {
            type: "string",
            description: "Token to deploy",
            required: true,
            choices: ["mim", "spell"],
            transform: (value: TaskArgValue) => (value as string).toUpperCase(),
        },
    },
    positionals: {
        name: "networks",
        description: "Networks to withdraw fees from",
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const tokenName = taskArgs.token as string;
    const lzDeployementConfig = await lz.getDeployementConfig(tooling, tokenName, taskArgs.from as NetworkName);

    let networks = Object.values(NetworkName);

    if (taskArgs.networks) {
        networks = taskArgs.networks as NetworkName[];
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
        const deployment = await tooling.getDeployment(lzDeployementConfig.feeHandler, chainId);
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
