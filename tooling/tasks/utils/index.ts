import {readdir} from "node:fs/promises";
import path from "path";
import {ethers} from "ethers";
import chalk from "chalk";
import crypto from "crypto";
import type {ERC20Meta, TaskArgValue} from "../../types";
import type {Tooling} from "../../tooling";

type ExecOptions = {
    env?: {[key: string]: string};
    noThrow?: boolean;
};

type ExitCode = number;

export const getFolders = async (rootDir: string): Promise<string[]> => {
    const entries = await readdir(rootDir, {withFileTypes: true});
    const folders = await Promise.all(
        entries.map(async (entry) => {
            const fullPath = path.join(rootDir, entry.name);
            if (entry.isDirectory()) {
                const subFolders = await getFolders(fullPath);
                return [fullPath, ...subFolders];
            }
            return [];
        })
    );
    return folders.flat();
};

export const formatDecimals = (value: bigint | string | number, decimals: number = 18): string => {
    let valueBn: bigint;

    if (typeof value === "string") {
        valueBn = BigInt(value);
    } else if (typeof value === "number") {
        valueBn = BigInt(value);
    } else {
        valueBn = value;
    }

    const formattedValue = ethers.formatUnits(valueBn, decimals);
    return parseFloat(formattedValue).toLocaleString("en-US");
};

export const exec = async (cmdLike: string[] | string, options?: ExecOptions): Promise<ExitCode> => {
    const cmd = Array.isArray(cmdLike) ? cmdLike.join(" ") : cmdLike;
    return new Promise(async (resolve, reject) => {
        const proc = Bun.spawn({
            cmd: cmd.split(" "),
            env: {
                ...options?.env,
                PATH: process.env.PATH,
            },
            onExit(_proc, exitCode, _signalCode, _error) {
                if (exitCode === 0) {
                    resolve(exitCode);
                } else if (options?.noThrow) {
                    resolve(exitCode || 1);
                } else {
                    reject(exitCode);
                }
            },
        });

        for await (const chunk of proc.stdout) {
            process.stdout.write(chunk);
        }
    });
};

const addressColors: {[address: string]: string} = {};

export const uniqueColorFromAddress = (address: `0x${string}`) => {
    if (!addressColors[address]) {
        const hash = crypto.createHash("md5").update(address).digest("hex");
        const color = `#${hash.slice(0, 6)}`;
        addressColors[address] = chalk.hex(color).bold(address);
    }
    return addressColors[address];
};

export const transferAmountStringToWei = (amount: TaskArgValue): string => {
    if (typeof amount !== "string") {
        console.log(`Invalid amount: ${amount}`);
        process.exit(1);
    }

    const lowerAmount = amount.toLowerCase();
    const [value, unit] = lowerAmount.match(/^(\d+(?:\.\d+)?)([a-z]+)?$/)?.slice(1) || [];
    const numericValue = parseFloat(value);

    if (unit) {
        switch (unit) {
            case "eth":
            case "ether":
                return ethers.parseEther(numericValue.toString()).toString();
            case "gwei":
                return ethers.parseUnits(numericValue.toString(), "gwei").toString();
            case "wei":
                return numericValue.toString();
            default:
                console.log(`Invalid unit: ${unit}`);
                process.exit(1);
        }
    }

    return BigInt(amount).toString();
};

export const showError = (desc: string, error: unknown) => {
    console.error(chalk.red(desc));
    if (error instanceof Error) {
        console.error(chalk.yellow(error.message));
        if (error.stack) {
            console.error(chalk.gray(error.stack));
        }
    } else {
        console.error(chalk.yellow("An unexpected error occurred:"), error);
    }
    process.exit(1);
};

export const isAddress = (address: string): boolean => {
    try {
        ethers.getAddress(address);
        return true;
    } catch (e) {
        return false;
    }
};

export const getERC20Meta = async (tooling: Tooling, token: `0x${string}`): Promise<ERC20Meta> => {
    try {
        const asset = await tooling.getContractAt("IERC20", token);
        const assetName = await asset.name();
        const assetSymbol = await asset.symbol();

        return {
            name: assetName,
            symbol: assetSymbol,
            decimals: Number(await asset.decimals()),
        };
    } catch (e) {
        console.error(`Couldn't retrieve underlying asset information for ${token}`);
        console.error(e);
        process.exit(1);
    }
};

export const printERC20Info = async (info: ERC20Meta) => {
    console.log(chalk.gray(`${info.name} [${info.symbol}]`));
    console.log(chalk.gray(`Decimals: ${info.decimals}`));
};

export const isValidPrivateKey = (privateKey: string): boolean => {
    try {
        new ethers.Wallet(privateKey);
        return true;
    } catch (error) {
        return false;
    }
};
