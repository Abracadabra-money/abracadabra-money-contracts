import {readdir} from "node:fs/promises";
import path from "path";
import {BigNumber, ethers} from "ethers";
import chalk from "chalk";
import crypto from "crypto";

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

export const formatDecimals = (value: BigInt | string | number, decimals: number = 18): string => {
    let valueBn: BigInt;

    if (typeof value === "string") {
        valueBn = BigInt(value);
    } else if (typeof value === "number") {
        valueBn = BigInt(value);
    } else {
        valueBn = value;
    }

    const formattedValue = ethers.utils.formatUnits(BigNumber.from(valueBn.toString()), decimals);
    return parseFloat(formattedValue).toLocaleString("en-US");
};

export const exec = async (cmdLike: string[] | string, options?: ExecOptions): Promise<ExitCode> => {
    const cmd = Array.isArray(cmdLike) ? cmdLike.join(" ") : cmdLike;
    return new Promise(async (resolve, reject) => {
        const proc = Bun.spawn({
            cmd: cmd.split(" "),
            env: options?.env,
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
