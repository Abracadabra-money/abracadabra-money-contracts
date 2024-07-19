import { ethers } from 'ethers';
import { tokenDeploymentNamePerNetwork, minterDeploymentNamePerNetwork, ownerPerNetwork } from '../utils/lz';
import type { TaskArgs, TaskFunction, TaskMeta, Tooling } from '../../types';

export const meta: TaskMeta = {
    name: 'lz:change-owners',
    description: 'Change the owner of token and minter contracts across multiple networks'
};

export const task: TaskFunction = async (_: TaskArgs, tooling: Tooling) => {
    const networks = tooling.getAllNetworks();

    for (const network of networks) {
        const config = tooling.getNetworkConfigByName(network);
        if (config.extra?.mimLzUnsupported) continue;
        
        const owner = ownerPerNetwork[network];
        const chainId = tooling.getChainIdByNetworkName(network);
        const tokenContract = await tooling.getContract(tokenDeploymentNamePerNetwork[network], chainId);
        const minterContract = minterDeploymentNamePerNetwork[network] ? await tooling.getContract(minterDeploymentNamePerNetwork[network], chainId) : undefined;

        console.log(`[${network}] Changing owner of ${tokenContract.address} to ${owner}...`);

        if (await tokenContract.owner() !== owner) {
            const tx = await tokenContract.transferOwnership(owner);
            console.log(`[${network}] Transaction: ${tx.hash}`);
            await tx.wait();
        } else {
            console.log(`[${network}] Owner is already ${owner}...`);
        }

        if (minterContract) {
            console.log(`[${network}] Changing owner of ${minterContract.address} to ${owner}...`);

            if (await minterContract.owner() !== owner) {
                const tx = await minterContract.transferOwnership(owner, true, false);
                console.log(`[${network}] Transaction: ${tx.hash}`);
                await tx.wait();
            } else {
                console.log(`[${network}] Owner is already ${owner}...`);
            }
        }
    }
};
