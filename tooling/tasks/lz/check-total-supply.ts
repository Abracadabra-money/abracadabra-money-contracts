import {BigNumber, ethers} from "ethers";
import {NetworkName, type TaskArgs, type TaskArgValue, type TaskFunction, type TaskMeta} from "../../types";
import chalk from "chalk";
import type {Tooling} from "../../tooling";
import {lz} from "../utils/lz";

export const meta: TaskMeta = {
    name: "lz/check-supply",
    description: "Check the total supply on alt chains against the locked amount on the token main chain",
    options: {
        token: {
            type: "string",
            description: "Token to deploy",
            required: true,
            choices: ["mim", "spell", "bspell"],
            transform: (value: TaskArgValue) => (value as string).toUpperCase(),
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    taskArgs.networks = Object.values(NetworkName);
    let altChainTotalSupply = BigNumber.from(0);
    let lockedAmount = BigNumber.from(0);
    const tokenName = taskArgs.token as string;
    const supportedNetworks = lz.getSupportedNetworks(tokenName);

    for (const network of supportedNetworks) {
        tooling.changeNetwork(network);

        const config = lz.getDeployementConfig(tooling, tokenName, network);
        const networkConfig = tooling.getNetworkConfigByName(network);
        const token = await tooling.getContractAt("IERC20", config.token);

        if (config.isNative) {
            const tokenContract = await tooling.getContract(config.oft, networkConfig.chainId);
            lockedAmount = await token.balanceOf(tokenContract.address);
            console.log(`[Main] ${network} Locked Amount: ${parseFloat(ethers.utils.formatEther(lockedAmount)).toLocaleString()}`);
        } else {
            const totalSupply = await token.totalSupply();
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
