import { BigNumber, ethers } from 'ethers';
import { NetworkName, type Network, type TaskArgs, type TaskFunction, type TaskMeta } from '../../types';
import fs from 'fs';
import path from 'path';
import chalk from 'chalk';
import type { Tooling } from '../../tooling';

export const meta: TaskMeta = {
    name: 'lz/check-mim-supply',
    description: 'Check the total supply of MIM on alt chains against the locked amount on Mainnet',
    options: {
        networks: {
            type: 'string',
            description: 'Networks to check',
            required: false,
        }
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    taskArgs.networks = Object.values(NetworkName);
    let altChainTotalSupply = BigNumber.from(0);
    let lockedAmount = BigNumber.from(0);

    for (const network of taskArgs.networks as NetworkName[]) {
        const config = tooling.getNetworkConfigByName(network);
        if(config.extra?.mimLzUnsupported) continue;

        tooling.changeNetwork(network);
        const mim = await tooling.getContractAt("IERC20", tooling.getAddressByLabel(network, "mim") as `0x${string}`);

        if (network === "mainnet") {
            const tokenContract = await tooling.getContract("Mainnet_ProxyOFTV2", 1);
            lockedAmount = await mim.balanceOf(tokenContract.address);
            console.log(`Mainnet Locked Amount: ${parseFloat(ethers.utils.formatEther(lockedAmount)).toLocaleString()}`);
        } else {
            const totalSupply = await mim.totalSupply();
            altChainTotalSupply = altChainTotalSupply.add(totalSupply);
            console.log(`${network}: ${parseFloat(ethers.utils.formatEther(totalSupply)).toLocaleString()}`);
        }
    }

    console.log("=======");
    console.log(`Mainnet Locked Amount: ${parseFloat(ethers.utils.formatEther(lockedAmount)).toLocaleString()}`);
    console.log(`Alt Chain Total Supply: ${parseFloat(ethers.utils.formatEther(altChainTotalSupply)).toLocaleString()}`);

    if (altChainTotalSupply.gt(lockedAmount)) {
        console.error("failed! Alt Chain Total Supply is greater than Mainnet Locked Amount");
        process.exit(1);
    } else {
        console.log(chalk.green("passed!"));
    }
};
