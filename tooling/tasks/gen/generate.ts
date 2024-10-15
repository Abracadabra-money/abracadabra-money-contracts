import {NetworkName, type BipsPercent, type NamedAddress, type TaskArgs, type TaskFunction, type TaskMeta} from "../../types";
import path from "path";
import fs from "fs";
import {formatDecimals, getFolders, transferAmountStringToWei} from "../utils";
import {input, confirm, number} from "@inquirer/prompts";
import select from "@inquirer/select";
import Handlebars from "handlebars";
import {$, Glob} from "bun";
import {ethers} from "ethers";
import chalk from "chalk";
import {rm} from "fs/promises";
import {CHAIN_NETWORK_NAME_PER_CHAIN_ID, type Tooling} from "../../tooling";
import {parse, visit} from "@solidity-parser/parser";

export const meta: TaskMeta = {
    name: "gen/gen",
    description: "Generate a script, interface, contract, test, cauldron deployment",
    options: {},
    positionals: {
        name: "template",
        description:
            "Template to generate [script, script:cauldron, interface, contract, contract:magic-vault, contract:upgradeable, test, deploy:mintable-erc20, mimswap:create-pool]",
        required: true,
    },
};

enum CollateralType {
    ERC20 = "ERC20",
    ERC4626 = "ERC4626",
    UNISWAPV3_LP = "UNISWAPV3_LP",
}

type CauldronScriptParameters = {
    collateral: {
        namedAddress: NamedAddress;
        aggregatorNamedAddress: NamedAddress;
        decimals: number;
        type: CollateralType;
    };

    parameters: {
        ltv: BipsPercent;
        interests: BipsPercent;
        borrowFee: BipsPercent;
        liquidationFee: BipsPercent;
    };
};

type NetworkSelection = {
    chainId: number;
    enumName: `ChainId.${string}`;
    name: NetworkName;
};

type ERC20Meta = {
    name: string;
    symbol: string;
    decimals: number;
};

enum PoolType {
    AMM,
    PEGGED,
    LOOSELY_PEGGED,
    BARELY_PEGGED,
}

let networks: {name: NetworkName; chainId: number}[] = [];
let tooling: Tooling;
let destinationFolders: string[] = [];

export const task: TaskFunction = async (taskArgs: TaskArgs, _tooling: Tooling) => {
    await $`bun run build`;

    tooling = _tooling;

    networks = Object.values(NetworkName).map((network) => ({
        name: network,
        chainId: tooling.config.networks[network as NetworkName].chainId,
    }));

    const srcFolder = path.join(tooling.config.foundry.src);
    const utilsFolder = path.join("utils");
    destinationFolders = [...(await getFolders(srcFolder)), ...(await getFolders(utilsFolder)), `${tooling.config.foundry.src}`];

    const glob = new Glob("*.s.sol");
    const scriptFiles = (await Array.fromAsync(glob.scan(tooling.config.foundry.script))).map((f) => {
        const name = path.basename(f).replace(".s.sol", "");
        return {
            name,
            value: name,
        };
    });

    taskArgs.template = (taskArgs.template as string[])[0] as string;

    switch (taskArgs.template) {
        case "script": {
            const scriptName = await input({message: "Script Name"});
            const filename = await input({message: "Filename", default: `${scriptName}.s.sol`});

            _writeTemplate("script", tooling.config.foundry.script, filename, {
                scriptName,
            });
            break;
        }
        case "script:cauldron": {
            const scriptName = await input({message: "Script Name"});
            const filename = await input({message: "Filename", default: `${scriptName}.s.sol`});

            _writeTemplate("script-cauldron", tooling.config.foundry.script, filename, {
                scriptName,
                ...(await _handleScriptCauldron(tooling)),
            });
            break;
        }
        case "interface": {
            const interfaceName = await input({message: "Interface Name"});
            const filename = await input({message: "Filename", default: `${interfaceName}.sol`});

            _writeTemplate("interface", `${tooling.config.foundry.src}/interfaces`, filename, {
                interfaceName,
            });
            break;
        }
        case "contract": {
            const contractName = await input({message: "Contract Name"});
            const filename = await input({message: "Filename", default: `${contractName}.sol`});
            const operatable = await confirm({message: "Operatable?", default: false});
            const destination = await _selectDestinationFolder();

            _writeTemplate("contract", destination, filename, {
                contractName,
                operatable,
            });
            break;
        }
        case "contract:upgradeable": {
            const contractName = await input({message: "Contract Name"});
            const filename = await input({message: "Filename", default: `${contractName}.sol`});
            const operatable = await confirm({message: "Operatable?", default: false});
            const destination = await _selectDestinationFolder();

            _writeTemplate("contract-upgradeable", destination, filename, {
                contractName,
                operatable,
            });
            break;
        }
        case "contract:magic-vault": {
            let name = await input({message: "Name"});

            if (name.startsWith("Magic")) {
                name = name.replace("Magic", "");
            }

            const filename = await input({message: "Filename", default: `Magic${name}.sol`});
            const destination = await _selectDestinationFolder("src", "src/tokens");
            const network = await _selectNetwork();
            const useDynamicName = await confirm({message: "Use Dynamic Name?", default: false});
            const asset = await _selectToken("Underlying Asset", network.name);
            const staking = await _inputAddress(network.name, "Staking", false);

            _writeTemplate("contract-magic-vault", destination, filename, {
                name,
                useDynamicName,
            });

            _writeTemplate("script-magic-vault", tooling.config.foundry.script, `Magic${name}.s.sol`, {
                name,
                timestamp: Math.floor(Date.now() / 1000),
                asset,
                staking,
            });

            break;
        }
        case "blast-wrapped": {
            const contractName = await input({message: "Contract Name"});
            const filename = await input({message: "Filename", default: `${contractName}.sol`});
            const destination = await _selectDestinationFolder();

            _writeTemplate("blast-wrapped", destination, filename, {
                contractName,
            });
            break;
        }
        case "test": {
            const modes = [
                {
                    name: "Simple",
                    value: "simple",
                },
                {
                    name: "Multi (base test-contract + per-suite-test-contract)",
                    value: "multi",
                },
            ];

            const testName = await input({message: "Test Name"});
            const scriptName = await select({
                message: "Script",
                choices: [{name: "(None)", value: "(None)"}, ...scriptFiles],
                default: testName,
            });
            const mode = await select({
                message: "Type",
                choices: modes,
            });
            const network = await _selectNetwork();
            const blockNumber = await input({message: "Block", default: "latest"});
            const filename = await input({message: "Filename", default: `${testName}.t.sol`});

            let parameters: {[key: string]: any} = {};

            parameters.testName = testName;
            parameters.scriptName = scriptName;
            parameters.mode = mode;
            parameters.network = network;
            parameters.blockNumber = blockNumber;

            let templateName = parameters.mode === "simple" ? "test" : "test-multi";

            if (parameters.scriptName === "(None)") {
                parameters.scriptName = undefined;
            }

            if (parameters.scriptName) {
                const solidityCode = fs.readFileSync(`${tooling.config.foundry.script}/${parameters.scriptName}.s.sol`, "utf8");

                try {
                    const ast = parse(solidityCode, {loc: true});
                    parameters.deployReturnValues = [];
                    parameters.deployVariables = [];

                    visit(ast, {
                        FunctionDefinition: (node) => {
                            if (node.name === "deploy" && node.isConstructor === false) {
                                if (node.returnParameters) {
                                    for (const param of node.returnParameters) {
                                        const obj = param as any;
                                        let typeName = obj.typeName.name || obj.namePath;
                                        const name = param.name || _generateUniqueCamelCaseName(typeName);

                                        if (typeName == "instance") {
                                            typeName = obj.typeName.namePath;
                                        }

                                        parameters.deployVariables.push(`${typeName} ${name}`);
                                        parameters.deployReturnValues.push(name);
                                    }
                                }
                            }
                        },
                    });
                } catch (e) {
                    console.error("Error parsing Solidity file:", e);
                }
            }

            if (parameters.blockNumber == "latest") {
                parameters.blockNumber = await tooling.getProvider().getBlockNumber();
                console.log(`Using Block: ${parameters.blockNumber}`);
            }

            parameters.blockNumber = parseInt(parameters.blockNumber);

            _writeTemplate(templateName, tooling.config.foundry.test, filename, parameters);
            break;
        }
        case "deploy:mintable-erc20": {
            const network = await _selectNetwork();
            const name = await input({message: "Token Name", default: "MyToken", required: true});
            const contractName = _sanitizeSolidityName(name);
            const symbol = await input({message: "Token Symbol", default: name, required: true});
            const decimals = await number({message: "Token Decimals", default: 18, required: true});
            const initialSupply = await _inputAmount("Initial Supply");

            const tokenFilename = `${contractName}.sol`;
            const tokenDestination = path.join(tooling.config.foundry.src, "tokens");
            console.log(chalk.gray(`Token Filename: ${tokenFilename}`));
            _writeTemplate("mintable-erc20", tokenDestination, tokenFilename, {
                contractName,
                name,
                symbol,
                decimals,
            });

            const scriptFilename = `${contractName}.s.sol`;
            const scriptDestination = tooling.config.foundry.script;
            console.log(chalk.gray(`Script Filename: ${scriptFilename}`));
            _writeTemplate("script-mintable-erc20", scriptDestination, scriptFilename, {
                name: contractName,
                initialSupply,
            });

            const deleteFiles = await confirm({message: "Delete generated files once done?", default: true});

            console.log(chalk.gray("---------------------------------"));
            console.log(chalk.gray(`Network: ${network.name}`));
            console.log(chalk.gray(`Token Name: ${name}`));
            console.log(chalk.gray(`Token Symbol: ${symbol}`));
            console.log(chalk.gray(`Token Decimals: ${decimals}`));
            console.log(chalk.gray(`Keep generated files: ${deleteFiles ? "No" : "Yes"}`));
            if (initialSupply) {
                console.log(chalk.gray(`Initial Supply: ${formatDecimals(initialSupply, decimals)}`));
            }
            console.log(chalk.gray("---------------------------------"));

            const confirmCreate = await confirm({message: "Create Token?", default: false});

            if (confirmCreate) {
                await _deploy(network.name, contractName);
            }

            if (deleteFiles) {
                await rm(path.join(tokenDestination, tokenFilename), {recursive: true, force: true});
                await rm(path.join(scriptDestination, scriptFilename), {recursive: true, force: true});
            } else {
                console.log(chalk.gray(`Token Contract: ${path.join(tokenDestination, tokenFilename)}`));
                console.log(chalk.gray(`Script Contract: ${path.join(scriptDestination, scriptFilename)}`));
            }

            break;
        }
        case "mimswap:create-pool": {
            const network = await _selectNetwork();
            const token0 = await _selectToken("Token 0", network.name);
            const token0Contract = await tooling.getContractAt("IERC20", token0.address);
            const token0Balance = await token0Contract.balanceOf((await tooling.getDeployer()).getAddress());

            const token0InitialAmmount = await input({message: `Initial amount (in wei) [in wallet: ${token0Balance}]`});
            const token0PriceInUsd = await input({message: `Price in USD`});

            const token1 = await _selectToken("Token 1", network.name);
            const token1Contract = await tooling.getContractAt("IERC20", token1.address);
            const token1Balance = await token1Contract.balanceOf((await tooling.getDeployer()).getAddress());

            const token1InitialAmmount = await input({message: `Initial amount (in wei) [in wallet: ${token1Balance}]`});
            const token1PriceInUsd = await input({message: `Price in USD`});

            const poolType = await select({
                message: "Pool Type",
                choices: [
                    {name: "AMM (similar to UniswapV2)", value: PoolType.AMM},
                    {name: "PEGGED (price fluctuables within 0.5%)", value: PoolType.PEGGED},
                    {name: "LOOSELY_PEGGED (price fluctuables within 1.25% [default for mim pools])", value: PoolType.LOOSELY_PEGGED},
                    {name: "BARELY_PEGGED (price fluctuables within 10%)", value: PoolType.BARELY_PEGGED},
                ],
            });

            const protocolOwnedPool = await confirm({message: "Is the pool owned by the protocol?", default: true});

            const deleteFiles = await confirm({message: "Delete generated files once done?", default: true});

            console.log(chalk.gray("---------------------------------"));
            console.log(chalk.gray(`Network: ${network.name}`));
            console.log(chalk.gray(`Token 0: ${token0.meta.name} [${token0.meta.symbol}]`));
            console.log(chalk.gray(`Token 0 Initial Amount: ${formatDecimals(token0InitialAmmount, token0.meta.decimals)}`));
            console.log(chalk.gray(`Token 0 Price in USD: ${token0PriceInUsd}`));
            console.log(chalk.gray(`Token 1: ${token1.meta.name} [${token1.meta.symbol}]`));
            console.log(chalk.gray(`Token 1 Initial Amount: ${formatDecimals(token1InitialAmmount, token1.meta.decimals)}`));
            console.log(chalk.gray(`Token 1 Price in USD: ${token1PriceInUsd}`));
            console.log(chalk.gray(`Pool Type: ${PoolType[poolType]}`));
            console.log(chalk.gray(`Keep generated files: ${deleteFiles ? "No" : "Yes"}`));

            const confirmDeployement = await confirm({message: "Create Pool?", default: false});
            const outputFilename = _writeTemplate("script-mimswap-create-pool", tooling.config.foundry.script, "MimswapCreatePool.s.sol", {
                token0: {
                    namedAddress: token0,
                    initialAmount: token0InitialAmmount,
                    priceInUsd: token0PriceInUsd,
                },
                token1: {
                    namedAddress: token1,
                    initialAmount: token1InitialAmmount,
                    priceInUsd: token1PriceInUsd,
                },
                poolType,
                protocolOwnedPool,
            });

            if (confirmDeployement) {
                await _deploy(network.name, "MimswapCreatePool");
            }

            if (deleteFiles) {
                await rm(outputFilename, {recursive: true, force: true});
            } else {
                console.log(chalk.gray(`Script Contract: ${outputFilename}`));
            }

            break;
        }
        default:
            console.error(`Template ${taskArgs.template} does not exist`);
            process.exit(1);
    }
};

const _deploy = async (chainNameOrId: NetworkName | number, scriptName: string) => {
    const networkConfig =
        typeof chainNameOrId === "string"
            ? tooling.getNetworkConfigByName(chainNameOrId as NetworkName)
            : tooling.getNetworkConfigByChainId(chainNameOrId as number);

    if (networkConfig.disableScript) {
        console.log(chalk.yellow(`Script deployment is disabled for ${networkConfig.name}.`));
        return;
    }

    const verifyFlag = !networkConfig.disableVerifyOnDeploy ? "--verify" : "";

    await $`forge clean`.nothrow();
    await $`bun task forge-deploy --broadcast ${verifyFlag} --network ${networkConfig.name} --script ${scriptName} --no-confirm`.nothrow();
};

const _writeTemplate = (templateName: string, destinationFolder: string, fileName: string, templateData: any): string => {
    const template = fs.readFileSync(`templates/${templateName}.hbs`, "utf8");

    const compiledTemplate = Handlebars.compile(template)(templateData);
    const file = `${destinationFolder}/${fileName}`;

    fs.writeFileSync(file, compiledTemplate);

    return file;
};

const _handleScriptCauldron = async (tooling: Tooling): Promise<CauldronScriptParameters> => {
    const network = await _selectNetwork();
    const collateralNamedAddress = await _inputAddress(network.name, "Collateral");
    const collateral = await tooling.getContractAt("IStrictERC20", collateralNamedAddress.address);

    let decimals: BigInt | undefined;
    let name: string | undefined;
    let symbol: string | undefined;

    try {
        console.log(chalk.gray(`${await collateral.name()} [${await collateral.symbol()}]`));
    } catch (e) {
        console.log(chalk.yellow(`Couldn't retrieve name and symbol`));
    }

    try {
        decimals = (await collateral.decimals()) as BigInt;
        console.log(chalk.gray(`Decimals: ${decimals}`));
    } catch (e) {}

    if (!decimals) {
        console.log(chalk.yellow(`Couldn't retrieve decimals, please specify manually`));
        decimals = BigInt(await input({message: "Decimals", required: true}));
    }

    const collateralType = await _selectCollateralType();
    let aggregatorNamedAddress: NamedAddress;

    switch (collateralType) {
        case CollateralType.ERC20:
            aggregatorNamedAddress = await _inputAggregator(network.name, `${name}[${symbol}] Aggregator Address`);
            break;
        case CollateralType.ERC4626:
            const erc4626Collateral = await tooling.getContractAt("IERC4626", collateralNamedAddress.address);
            const info = await _getERC20Meta(await erc4626Collateral.asset());
            aggregatorNamedAddress = await _inputAggregator(network.name, `${info.name}[${info.symbol}] Aggregator Address`);
            break;
        case CollateralType.UNISWAPV3_LP:
            console.log(chalk.yellow("Uniswap V3 LP collateral type is not supported yet"));
            process.exit(1);
    }

    return {
        collateral: {
            namedAddress: collateralNamedAddress,
            decimals: Number(decimals),
            aggregatorNamedAddress,
            type: collateralType,
        },
        parameters: {
            ltv: await _inputBipsAsPercent("LTV"),
            interests: await _inputBipsAsPercent("Interests"),
            borrowFee: await _inputBipsAsPercent("Borrow Fee"),
            liquidationFee: await _inputBipsAsPercent("Liquidation Fee"),
        },
    };
};

const _selectToken = async (label: string, networkName: NetworkName): Promise<NamedAddress & {meta: ERC20Meta}> => {
    const tokenNamedAddress = await _inputAddress(networkName, label);
    const info = await _getERC20Meta(tokenNamedAddress.address);
    _printERC20Info(info);
    return {...tokenNamedAddress, meta: info};
};

const _getERC20Meta = async (token: `0x${string}`): Promise<ERC20Meta> => {
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

const _printERC20Info = async (info: ERC20Meta) => {
    console.log(chalk.gray(`${info.name} [${info.symbol}]`));
    console.log(chalk.gray(`Decimals: ${info.decimals}`));
};

const _selectCollateralType = async (): Promise<CollateralType> => {
    return await select({
        message: "Collateral Type",
        choices: [
            {name: "ERC20", value: CollateralType.ERC20},
            {name: "ERC4626", value: CollateralType.ERC4626},
            {name: "Uniswap V3 LP", value: CollateralType.UNISWAPV3_LP},
        ],
    });
};

const _inputAddress = async <B extends boolean = true>(
    networkName: NetworkName,
    message: string,
    required: B = true as B
): Promise<B extends true ? NamedAddress : NamedAddress | undefined> => {
    let address: `0x${string}` | undefined;
    let name: string | undefined;

    const _message = required ? `${message} (name or 0x...)` : `${message} (name, 0x... or empty to ignore)`;

    while (!address && !name) {
        const answer = await input({message: _message, required});

        if (!answer && !required) {
            return undefined as any;
        }

        if (_isAddress(answer)) {
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
        address: ethers.utils.getAddress(address as string) as `0x${string}`,
        name,
    };
};

const _inputAggregator = async (networkName: NetworkName, message: string): Promise<NamedAddress> => {
    const namedAddress = await _inputAddress(networkName, message);

    // use IAggregator to query the chainlink oracle
    const aggregator = await tooling.getContractAt("IAggregatorWithMeta", namedAddress.address);

    try {
        try {
            const name = await aggregator.description();
            console.log(chalk.gray(`Name: ${name}`));
        } catch (e) {}

        const decimals = await aggregator.decimals();
        console.log(chalk.gray(`Decimals: ${decimals}`));

        const latestRoundData = await aggregator.latestRoundData();
        const priceInUsd = Number(latestRoundData[1]) / 10 ** decimals;
        console.log(chalk.gray(`Price: ${priceInUsd} USD`));
    } catch (e) {
        console.error(`Couldn't retrieve aggregator information for ${namedAddress}`);
        console.error(e);
        process.exit(1);
    }

    return namedAddress;
};

const _inputBipsAsPercent = async (
    message: string
): Promise<{
    bips: number;
    percent: number;
}> => {
    const percent = Number(
        await input({
            message: `${message} [0...100]`,
            required: true,
            validate: (valueStr: string) => {
                const value = Number(valueStr);
                return value >= 0 && value <= 100;
            },
        })
    );

    // convert percent to bips and make sure it's an integer between 0 and 10000
    return {
        bips: Math.round(percent * 100),
        percent,
    };
};

const _inputAmount = async (message: string, defaultValue?: string): Promise<string> => {
    const amountString = await input({
        message: `${message} (in token units ex: 100eth, default is wei)`,
        default: defaultValue,
    });
    return transferAmountStringToWei(amountString);
};

const _selectDestinationFolder = async (root?: string, defaultFolder?: string) => {
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

const _selectNetwork = async (): Promise<NetworkSelection> => {
    const network = await select({
        message: "Network",
        choices: networks.map((network) => ({
            name: network.name,
            value: {chainId: network.chainId, name: network.name},
        })),
    });

    return {
        ...network,
        enumName: `ChainId.${CHAIN_NETWORK_NAME_PER_CHAIN_ID[network.chainId]}`,
    };
};

const _isAddress = (address: string): boolean => {
    try {
        ethers.utils.getAddress(address);
        return true;
    } catch (e) {
        return false;
    }
};

const _generateUniqueCamelCaseName = (namePath: string): string => {
    return namePath
        .split(".")
        .map((part, index) => (index === 0 ? part.toLowerCase() : part.charAt(0).toUpperCase() + part.slice(1)))
        .join("");
};

const _sanitizeSolidityName = (name: string): string => {
    // Remove any characters that are not alphanumeric or underscore
    let sanitized = name.replace(/[^a-zA-Z0-9_]/g, "");

    // Ensure the name starts with a letter or underscore
    if (!/^[a-zA-Z_]/.test(sanitized)) {
        sanitized = "_" + sanitized;
    }

    // Ensure the name is not empty
    if (sanitized.length === 0) {
        throw new Error("Invalid name");
    }

    return sanitized;
};

Handlebars.registerHelper("printAddress", (namedAddress: NamedAddress) => {
    return namedAddress.name ? new Handlebars.SafeString(`toolkit.getAddress("${namedAddress.name}")`) : namedAddress.address;
});

Handlebars.registerHelper("ifeq", function (this: any, arg1: any, arg2: any, options: Handlebars.HelperOptions) {
    return arg1 === arg2 ? options.fn(this) : options.inverse(this);
});
