import {ethers} from "ethers";
import type {NetworkName, TaskArgs, TaskFunction, TaskMeta} from "../../types";
import type {Tooling} from "../../tooling";
import * as inputs from "../utils/inputs";
import {getPoolCreationParams, createPool, PoolType, type TokenInfo} from "../../mimswap";
import chalk from "chalk";

export const meta: TaskMeta = {
    name: "mimswap/create-pool",
    description: "Create a new MimSwap pool",
    options: {
        network: {
            type: "string",
            description: "The network to create the pool on",
            required: true,
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const network = taskArgs.network as NetworkName;
    console.log(chalk.cyan(`Creating a new MimSwap pool on ${network}`));

    const poolType = await inputs.selectPoolType([
        {name: "AMM", value: PoolType.AMM},
        {name: "Pegged", value: PoolType.PEGGED},
        {name: "Loosely Pegged", value: PoolType.LOOSELY_PEGGED},
        {name: "Barely Pegged", value: PoolType.BARELY_PEGGED},
    ]);

    console.log(chalk.gray("Base Token Information"));
    const baseToken = await inputs.selectToken("Base Token", network);
    const baseAmount = await inputs.inputTokenAmount("Base Token Amount");
    const basePriceInUsd = await inputs.inputFloat("Base Token Price in USD");

    console.log(chalk.gray("Quote Token Information"));
    const quoteToken = await inputs.selectToken("Quote Token", network);
    const quoteAmount = await inputs.inputTokenAmount("Quote Token Amount");
    const quotePriceInUsd = await inputs.inputFloat("Quote Token Price in USD");

    const protocolOwnedPool = await inputs.confirmInput("Is this a protocol-owned pool?", true);

    const base: TokenInfo = {
        token: baseToken.address,
        amount: baseAmount,
        priceInUsd: basePriceInUsd,
    };

    const quote: TokenInfo = {
        token: quoteToken.address,
        amount: quoteAmount,
        priceInUsd: quotePriceInUsd,
    };

    const poolParams = await getPoolCreationParams(poolType as PoolType, base, quote, protocolOwnedPool);

    console.log(chalk.cyan("Pool Creation Summary:"));
    console.log(chalk.gray(`Network: ${network}`));
    console.log(chalk.gray(`Pool Type: ${PoolType[poolType as keyof typeof PoolType]}`));
    console.log(chalk.gray(`Base Token: ${baseToken.meta.symbol} (${baseToken.address})`));
    console.log(chalk.gray(`Base Amount: ${ethers.formatUnits(baseAmount, baseToken.meta.decimals)}`));
    console.log(chalk.gray(`Base Price: $${basePriceInUsd}`));
    console.log(chalk.gray(`Quote Token: ${quoteToken.meta.symbol} (${quoteToken.address})`));
    console.log(chalk.gray(`Quote Amount: ${ethers.formatUnits(quoteAmount, quoteToken.meta.decimals)}`));
    console.log(chalk.gray(`Quote Price: $${quotePriceInUsd}`));
    console.log(chalk.gray(`Protocol Owned: ${protocolOwnedPool}`));
    console.log();
    console.log(chalk.cyan("Raw Pool Parameters:"));
    console.log(chalk.gray(`feeRate: ${poolParams.feeRate}`));
    console.log(chalk.gray(`I: ${poolParams.i}`));
    console.log(chalk.gray(`K: ${poolParams.poolType}`));
    console.log(chalk.gray(`Predicted Address: ${poolParams.predictedAddress}`));

    const confirm = await inputs.confirmInput("Do you want to create this pool?", false);

    if (confirm) {
        try {
            console.log(chalk.yellow("Creating pool..."));
            const { receipt, clone, shares } = await createPool(poolParams);
            console.log(chalk.green("Pool created successfully!"));
            console.log(chalk.gray(`Transaction Hash: ${receipt.transactionHash}`));
            console.log(chalk.gray(`Pool Address: ${clone}`));
            console.log(chalk.gray(`LP Shares: ${shares}`));
        } catch (error) {
            console.error(chalk.red("Error creating pool:"), error);
        }
    } else {
        console.log(chalk.yellow("Pool creation cancelled."));
    }
};
