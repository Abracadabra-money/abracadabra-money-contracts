import {input, confirm, number} from "@inquirer/prompts";
import select from "@inquirer/select";
import {ethers} from "ethers";
import chalk from "chalk";
import {CollateralType, NetworkName, type BipsPercent, type ERC20Meta, type NamedAddress} from "../../types";
import {getERC20Meta, getFolders, isAddress, printERC20Info, transferAmountStringToWei} from "./index";
import {tooling} from "../../tooling";
import path from "path";
import {Glob} from "bun";

let destinationFolders: string[] = [];
let networks: {name: NetworkName; chainId: number}[] = [];
let scriptFiles: {name: string; value: string}[] = [];

export const init = async () => {
    const srcFolder = path.join(tooling.config.foundry.src);
    const utilsFolder = path.join("utils");

    networks = Object.values(NetworkName).map((network) => ({
        name: network,
        chainId: tooling.config.networks[network as NetworkName].chainId,
    }));

    const glob = new Glob("*.s.sol");

    scriptFiles = (await Array.fromAsync(glob.scan(tooling.config.foundry.script))).map((f) => {
        const name = path.basename(f).replace(".s.sol", "");
        return {
            name,
            value: name,
        };
    });

    destinationFolders = [...(await getFolders(srcFolder)), ...(await getFolders(utilsFolder)), `${tooling.config.foundry.src}`];
};

export const inputText = async (message: string, defaultValue?: string) => {
    return await input({message, default: defaultValue});
};

export const inputNumber = async (message: string, defaultValue?: number) => {
    return await number({message, default: defaultValue});
};

export const confirmInput = async (message: string, defaultValue: boolean = false) => {
    return await confirm({message, default: defaultValue});
};

export const selectInput = async <T>(message: string, choices: Array<{name: string; value: T}>, defaultValue?: T) => {
    return await select({message, choices, default: defaultValue});
};

export const inputAddress = async <B extends boolean = true>(
    networkName: NetworkName,
    message: string,
    required: B = true as B,
): Promise<B extends true ? NamedAddress : NamedAddress | undefined> => {
    let address: `0x${string}` | undefined;
    let name: string | undefined;

    const _message = required ? `${message} (name or 0x...)` : `${message} (name, 0x... or empty to ignore)`;

    while (!address && !name) {
        const answer = await input({message: _message, required});

        if (!answer && !required) {
            return undefined as any;
        }

        if (isAddress(answer)) {
            address = answer as `0x${string}`;
            name = tooling.getLabelByAddress(networkName, address);
        } else {
            address = tooling.getAddressByLabel(networkName, answer);

            if (address) {
                name = answer;
            } else {
                console.log(chalk.yellow(`Address for ${answer} not found`));
            }
        }
    }

    console.log(chalk.gray(`Address: ${address} ${name ? `(${name})` : ""}`));

    return {
        address: ethers.getAddress(address as string) as `0x${string}`,
        name,
    };
};

export const inputAggregator = async (networkName: NetworkName, message: string): Promise<NamedAddress> => {
    const namedAddress = await inputAddress(networkName, message);
    const aggregator = await tooling.getContractAt("IAggregatorWithMeta", namedAddress.address);

    try {
        try {
            const name = await aggregator.description();
            console.log(chalk.gray(`Name: ${name}`));
        } catch (e) {
            
        }

        const decimals = await aggregator.decimals();
        console.log(chalk.gray(`Decimals: ${decimals}`));

        const latestRoundData = await aggregator.latestRoundData();
        console.log(latestRoundData);
        // Convert BigInt to number before performing the calculation
        const priceInUsd = Number(latestRoundData[1]) / Math.pow(10, Number(decimals));
        console.log(chalk.gray(`Price: ${priceInUsd} USD`));
    } catch (e) {
        console.error(`Couldn't retrieve aggregator information for ${namedAddress}`);
        console.error(e);
        process.exit(1);
    }

    return namedAddress;
};

export const inputBipsAsPercent = async (message: string): Promise<BipsPercent> => {
    const percent = Number(
        await input({
            message: `${message} [0...100]`,
            required: true,
            validate: (valueStr: string) => {
                const value = Number(valueStr);
                return value >= 0 && value <= 100;
            },
        }),
    );

    return {
        bips: Math.round(percent * 100),
        percent,
    };
};

export const inputTokenAmount = async (message: string, defaultValue?: string): Promise<string> => {
    const amountString = await input({
        message: `${message} (in token units ex: 100eth, default is wei)`,
        default: defaultValue,
    });
    return transferAmountStringToWei(amountString);
};

export const inputFloat = async (message: string, defaultValue?: string): Promise<number> => {
    const amountString = await input({
        message,
        default: defaultValue,
    });

    return parseFloat(amountString);
};

export const selectDestinationFolder = async (root?: string, defaultFolder?: string) => {
    return await select({
        message: "Destination Folder",
        choices: destinationFolders
            .map((folder) => {
                if (!root || (root && folder.startsWith(root))) {
                    return {name: folder, value: folder};
                }
                return undefined;
            })
            .filter((folder) => folder !== undefined),
        default: defaultFolder,
    });
};

export const selectNetwork = async (): Promise<{
    chainId: number;
    name: NetworkName;
}> => {
    return await select({
        message: "Network",
        choices: networks.map((network) => ({
            name: network.name,
            value: {chainId: network.chainId, name: network.name},
        })),
    });
};

export const selectCollateralType = async (): Promise<CollateralType> => {
    return await select({
        message: "Collateral Type",
        choices: [
            {name: "ERC20", value: CollateralType.ERC20},
            {name: "ERC4626", value: CollateralType.ERC4626},
            {name: "Uniswap V3 LP", value: CollateralType.UNISWAPV3_LP},
        ],
    });
};

export const selectPoolType = async (poolTypes: Array<{name: string; value: string | number}>): Promise<string | number> => {
    return await select({
        message: "Pool Type",
        choices: poolTypes,
    });
};

export const selectScript = async (defaultValue?: string): Promise<string> => {
    return await select({
        message: "Script",
        choices: [{name: "(None)", value: "(None)"}, ...scriptFiles],
        default: defaultValue,
    });
};

export const selectToken = async (label: string, networkName: NetworkName): Promise<NamedAddress & {meta: ERC20Meta}> => {
    const tokenNamedAddress = await inputAddress(networkName, label);
    const info = await getERC20Meta(tooling, tokenNamedAddress.address);
    printERC20Info(info);
    return {...tokenNamedAddress, meta: info};
};
