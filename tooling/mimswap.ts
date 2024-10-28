import {ethers} from "ethers";
import {tooling} from "./tooling";
import chalk from "chalk";
import type {TransactionReceipt} from "ethers";

export enum PoolType {
    AMM = "1000000000000000000",
    PEGGED = "100000000000000", // price fluctuables within 0.5%
    LOOSELY_PEGGED = "250000000000000", // price fluctuables within 1.25%
    BARELY_PEGGED = "2000000000000000", // price fluctuables within 10%
}

export enum FeeRate {
    AMM = "3000000000000000", // 0.3%
    PEGGED = "500000000000000", // 0.05%
}

export interface TokenInfo {
    token: string;
    amount: string;
    priceInUsd: number;
}

export type PoolCreationParams = {
    baseToken: string;
    quoteToken: string;
    feeRate: FeeRate;
    i: string;
    poolType: PoolType;
    creator: string;
    baseAmount: string;
    quoteAmount: string;
    protocolOwnedPool: boolean;
    predictedAddress: string;
};

export const getPoolCreationParams = async (
    poolType: PoolType,
    base: TokenInfo,
    quote: TokenInfo,
    protocolOwnedPool: boolean
): Promise<PoolCreationParams & {predictedAddress: string}> => {
    const deployer = await tooling.getOrLoadDeployer();
    const baseToken = await tooling.getContractAt("IERC20", base.token as `0x${string}`);
    const quoteToken = await tooling.getContractAt("IERC20", quote.token as `0x${string}`);

    const i = await calculateI(base.priceInUsd, quote.priceInUsd, await baseToken.decimals(), await quoteToken.decimals());

    const feeRate = poolType === PoolType.AMM ? FeeRate.AMM : FeeRate.PEGGED;

    const creator = await deployer.getAddress();

    const factory = await tooling.getContractAt(
        "IFactory",
        (await tooling.getAddressByLabel(tooling.network.name, "mimswap.factory")) as `0x${string}`
    );

    const predictedAddress = await factory.predictDeterministicAddress(
        creator,
        base.token,
        quote.token,
        feeRate,
        i,
        poolType,
        protocolOwnedPool
    );

    return {
        baseToken: base.token,
        quoteToken: quote.token,
        feeRate,
        i,
        poolType,
        creator,
        baseAmount: base.amount,
        quoteAmount: quote.amount,
        protocolOwnedPool,
        predictedAddress,
    };
};

export const createPool = async (params: PoolCreationParams & {predictedAddress: string}): Promise<TransactionReceipt> => {
    const deployer = await tooling.getOrLoadDeployer();
    const router = await tooling.getContractAt(
        "Router",
        (await tooling.getAddressByLabel(tooling.network.name, "mimswap.router")) as `0x${string}`
    );

    const factory = await tooling.getContractAt(
        "IFactory",
        (await tooling.getAddressByLabel(tooling.network.name, "mimswap.factory")) as `0x${string}`
    );

    // Check if pool already exists
    const poolExists = await factory.poolExists(params.predictedAddress);
    if (poolExists) {
        throw new Error("Pool with these parameters already exists");
    }

    const baseToken = await tooling.getContractAt("IERC20", params.baseToken as `0x${string}`);
    const quoteToken = await tooling.getContractAt("IERC20", params.quoteToken as `0x${string}`);
    const baseAllowance = await baseToken.allowance(params.creator, router.address);
    const quoteAllowance = await quoteToken.allowance(params.creator, router.address);

    if (baseAllowance < params.baseAmount) {
        console.log(chalk.gray(`Approving base token ${params.baseToken} for ${params.baseAmount} amount...`));
        await (await baseToken.connect(deployer).approve(router.address, params.baseAmount)).wait();
    }

    if (quoteAllowance < params.quoteAmount) {
        console.log(chalk.gray(`Approving quote token ${params.quoteToken} for ${params.quoteAmount} amount...`));
        await (await quoteToken.connect(deployer).approve(router.address, params.quoteAmount)).wait();
    }

    // Simulate the transaction
    try {
        console.log(chalk.gray("Simulating the transaction"));
        await router
            .connect(deployer)
            .createPool.staticCall(
                params.baseToken,
                params.quoteToken,
                params.feeRate,
                params.i,
                params.poolType,
                params.creator,
                params.baseAmount,
                params.quoteAmount,
                params.protocolOwnedPool
            );
    } catch (error) {
        console.error("Simulation failed:", error);
        throw new Error("Pool creation simulation failed");
    }

    console.log(chalk.gray("Sending the transaction..."));

    // If simulation succeeds, send the actual transaction
    return await (
        await router
            .connect(deployer)
            .createPool(
                params.baseToken,
                params.quoteToken,
                params.feeRate,
                params.i,
                params.poolType,
                params.creator,
                params.baseAmount,
                params.quoteAmount,
                params.protocolOwnedPool
            )
    ).wait();
};

export const calculateI = async (
    basePriceInUSD: number,
    quotePriceInUSD: number,
    baseDecimals: bigint,
    quoteDecimals: bigint
): Promise<string> => {
    const baseScale = BigInt(10) ** BigInt(18n + quoteDecimals);
    const quoteScale = BigInt(10) ** BigInt(baseDecimals);

    const scaledBasePriceInUSD = ethers.parseUnits(basePriceInUSD.toString(), 18) * baseScale;
    const scaledQuotePriceInUSD = ethers.parseUnits(quotePriceInUSD.toString(), 18) * quoteScale;

    return (scaledBasePriceInUSD / scaledQuotePriceInUSD).toString();
};
