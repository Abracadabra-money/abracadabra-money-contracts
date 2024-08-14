import type { ContractInterface } from 'ethers';
import type { TaskArgs, TaskFunction, TaskMeta, Tooling } from '../../types';
import { feeHandlerDeployments } from '../utils/lz';

export const meta: TaskMeta = {
    name: 'lz/oft:withdraw-fees',
    description: 'Withdraw fees from fee handlers on multiple networks',
    options: {},
    positionals: {
        name: 'networks',
        description: 'Networks to withdraw fees from',
    }
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    let networks = Object.keys(tooling.config.networks);

    if (taskArgs.networks) {
        networks = taskArgs.networks as string[];
    }

    for (const network of networks) {
        const abi = [{
            "inputs": [],
            "name": "withdrawFees",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        }] as ContractInterface;

        await tooling.changeNetwork(network);
        const chainId = tooling.getChainIdByNetworkName(network);
        const deployment = await tooling.getDeployment(feeHandlerDeployments[network], chainId);
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