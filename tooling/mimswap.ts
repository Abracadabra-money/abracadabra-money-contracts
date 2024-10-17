import {ethers} from "ethers";
import {tooling} from "./tooling";
import chalk from "chalk";

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
    protocolOwnedPool: boolean,
): Promise<PoolCreationParams & { predictedAddress: string }> => {
    const signer = await tooling.getDeployer();

    const baseToken = await tooling.getContractAt("IERC20", base.token as `0x${string}`);
    const quoteToken = await tooling.getContractAt("IERC20", quote.token as `0x${string}`);

    const i = await calculateI(base.priceInUsd, quote.priceInUsd, await baseToken.decimals(), await quoteToken.decimals());

    const feeRate = poolType === PoolType.AMM ? FeeRate.AMM : FeeRate.PEGGED;

    const creator = await signer.getAddress();

    const factory = await tooling.getContractAt(
        "IFactory",
        (await tooling.getAddressByLabel(tooling.network.name, "mimswap.factory")) as `0x${string}`,
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

    console.log(chalk.gray(`Pool address: ${predictedAddress}`));

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

export const createPool = async (params: PoolCreationParams & { predictedAddress: string }): Promise<{receipt: any; clone: string; shares: string}> => {
    const router = await tooling.getContractAt(
        "Router",
        (await tooling.getAddressByLabel(tooling.network.name, "mimswap.router")) as `0x${string}`,
    );

    const factory = await tooling.getContractAt(
        "IFactory",
        (await tooling.getAddressByLabel(tooling.network.name, "mimswap.factory")) as `0x${string}`,
    );

    // Check if pool already exists
    const poolExists = await factory.poolExists(params.predictedAddress);
    if (poolExists) {
        throw new Error("Pool with these parameters already exists");
    }

    const baseToken = await tooling.getContractAt("IERC20", params.baseToken as `0x${string}`);
    const quoteToken = await tooling.getContractAt("IERC20", params.quoteToken as `0x${string}`);

    // Check allowances before approving
    const baseAllowance = await baseToken.allowance(params.creator, router.address);
    const quoteAllowance = await quoteToken.allowance(params.creator, router.address);

    if (baseAllowance.lt(params.baseAmount)) {
        console.log(chalk.gray(`Approving base token ${params.baseToken} for ${params.baseAmount} amount`));
        await (await baseToken.approve(router.address, params.baseAmount)).wait();
    }

    if (quoteAllowance.lt(params.quoteAmount)) {
        console.log(chalk.gray(`Approving quote token ${params.quoteToken} for ${params.quoteAmount} amount`));
        await (await quoteToken.approve(router.address, params.quoteAmount)).wait();
    }

    // Simulate the transaction
    try {
        await router.callStatic.createPool(
            params.baseToken,
            params.quoteToken,
            params.feeRate,
            params.i,
            params.poolType,
            params.creator,
            params.baseAmount,
            params.quoteAmount,
            params.protocolOwnedPool,
        );
    } catch (error) {
        console.error("Simulation failed:", error);
        throw new Error("Pool creation simulation failed");
    }

    // If simulation succeeds, send the actual transaction
    const tx = await router.createPool(
        params.baseToken,
        params.quoteToken,
        params.feeRate,
        params.i,
        params.poolType,
        params.creator,
        params.baseAmount,
        params.quoteAmount,
        params.protocolOwnedPool,
    );

    const receipt = await tx.wait();
    const event = receipt.events?.find((e: any) => e.event === "LogCreated");

    if (!event) {
        throw new Error("Pool creation event (LogCreated) not found");
    }

    return {
        receipt,
        clone: event.args.clone_,
        shares: event.args.k_.toString(),
    };
};

export const calculateI = async (
    basePriceInUSD: number,
    quotePriceInUSD: number,
    baseDecimals: number,
    quoteDecimals: number,
): Promise<string> => {
    const baseScale = ethers.BigNumber.from(10).pow(18 + quoteDecimals);
    const quoteScale = ethers.BigNumber.from(10).pow(baseDecimals);

    const scaledBasePriceInUSD = ethers.utils.parseUnits(basePriceInUSD.toString(), 18).mul(baseScale);
    const scaledQuotePriceInUSD = ethers.utils.parseUnits(quotePriceInUSD.toString(), 18).mul(quoteScale);

    return scaledBasePriceInUSD.div(scaledQuotePriceInUSD).toString();
};
