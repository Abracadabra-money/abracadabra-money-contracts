import type {InterfaceAbi} from "ethers";
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
        ] as const;

        await tooling.changeNetwork(network);
        const deployer = await tooling.getOrLoadDeployer();
        const chainId = tooling.getChainIdByName(network);
        const lzDeployementConfig = await lz.getDeployementConfig(tooling, tokenName, network);
        const deployment = await tooling.getDeployment(lzDeployementConfig.feeHandler, chainId);
        const feeHandler = await tooling.getContractAt(abi as InterfaceAbi, deployment.address);

        console.log(`[${network}] ⏳ Withdrawing Fee...`);

        // only withdraw when there's ETH in the contract
        const balance = await tooling.getProvider().getBalance(deployment.address);
        if (balance === 0n) {
            console.log("Nothing to withdraw");
            continue;
        }

        const tx = await feeHandler.connect(deployer).withdrawFees();
        const receipt = await tx.wait();
        console.log(`${receipt?.hash}`);
    }
};
