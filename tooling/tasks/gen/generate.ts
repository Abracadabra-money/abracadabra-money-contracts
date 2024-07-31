import type {TaskArgs, TaskFunction, TaskMeta, Tooling} from "../../types";
import path from "path";
import fs from "fs";
import {getFolders} from "../utils";
import {input, confirm} from "@inquirer/prompts";
import select from "@inquirer/select";
import Handlebars from "handlebars";
import {Glob} from "bun";
import {ethers} from "ethers";
import chalk from "chalk";

export const meta: TaskMeta = {
    name: "gen:gen",
    description: "Generate a script, interface, contract, test, cauldron deployment",
    options: {},
    positionals: {
        name: "template",
        description: "Template to generate [script, interface, contract, test, script:cauldron]",
        required: true,
    },
};

type BipsPercent = {
    bips: number;
    percent: number;
};

type CauldronScriptParameters = {
    collateral: {
        name: string;
        address: string;
        decimals: number;
        aggregatorAddress: string;
    };

    parameters: {
        ltv: BipsPercent;
        interests: BipsPercent;
        borrowFee: BipsPercent;
        liquidationFee: BipsPercent;
    };
};

type NetworkSelection = {
    chainId: string;
    name: string;
};

let networks: {name: string; chainId: number}[] = [];
let chainIdEnum: {[key: string]: string} = {};
let tooling: Tooling;

export const task: TaskFunction = async (taskArgs: TaskArgs, _tooling: Tooling) => {
    tooling = _tooling;

    networks = Object.keys(tooling.config.networks).map((network) => ({
        name: network,
        chainId: tooling.config.networks[network].chainId,
    }));

    chainIdEnum = Object.keys(tooling.config.networks).reduce((acc, network) => {
        const capitalizedNetwork = network.charAt(0).toUpperCase() + network.slice(1);
        return {...acc, [tooling.config.networks[network].chainId]: capitalizedNetwork};
    }, {}) as {[key: string]: string};

    let answers: any = {};

    const srcFolder = path.join(tooling.config.foundry.src);
    const utilsFolder = path.join("utils");

    const destinationFolders = [...(await getFolders(srcFolder)), ...(await getFolders(utilsFolder)), `${tooling.config.foundry.src}`];

    const glob = new Glob("*.s.sol");
    const scriptFiles = (await Array.fromAsync(glob.scan(tooling.config.foundry.script))).map((f) => {
        const name = path.basename(f).replace(".s.sol", "");
        return {
            name,
            value: name,
        };
    });

    const promptDestinationFolder = async () => {
        return await select({
            message: "Destination Folder",
            choices: destinationFolders.map((folder) => ({name: folder, value: folder})),
        });
    };

    taskArgs.template = (taskArgs.template as string[])[0] as string;

    switch (taskArgs.template) {
        case "script": {
            const scriptName = await input({message: "Script Name"});
            const filename = await input({message: "Filename", default: `${scriptName}.s.sol`});

            answers.scriptName = scriptName;
            answers.filename = filename;
            answers.destination = tooling.config.foundry.script;
            break;
        }
        case "script:cauldron": {
            const scriptName = await input({message: "Script Name"});
            const filename = await input({message: "Filename", default: `${scriptName}.s.sol`});

            taskArgs.template = "script-cauldron";
            answers.scriptName = scriptName;
            answers.filename = filename;
            answers.destination = tooling.config.foundry.script;

            answers = {
                ...answers,
                ...(await _handleScriptCauldron(tooling)),
            };

            break;
        }
        case "interface": {
            const interfaceName = await input({message: "Interface Name"});
            const filename = await input({message: "Filename", default: `${interfaceName}.sol`});

            answers.interfaceName = interfaceName;
            answers.filename = filename;
            answers.destination = `${tooling.config.foundry.src}/interfaces`;
            break;
        }
        case "contract": {
            const contractName = await input({message: "Contract Name"});
            const filename = await input({message: "Filename", default: `${contractName}.sol`});
            const operatable = await confirm({message: "Operatable?", default: false});
            const destination = await promptDestinationFolder();

            answers.contractName = contractName;
            answers.filename = filename;
            answers.destination = destination;
            answers.operatable = operatable;
            break;
        }
        case "blast-wrapped": {
            const contractName = await input({message: "Contract Name"});
            const filename = await input({message: "Filename", default: `${contractName}.sol`});
            const destination = await promptDestinationFolder();
            answers.contractName = contractName;
            answers.filename = filename;
            answers.destination = destination;
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
            const network = _selectNetwork();
            const blockNumber = await input({message: "Block", default: "latest"});
            const filename = await input({message: "Filename", default: `${testName}.t.sol`});

            answers.testName = testName;
            answers.scriptName = scriptName;
            answers.mode = mode;
            answers.network = network;
            answers.blockNumber = blockNumber;
            answers.filename = filename;
            answers.destination = tooling.config.foundry.test;

            if (answers.mode === "multi") {
                taskArgs.template = "test-multi";
            }

            if (answers.scriptName === "(None)") {
                answers.scriptName = undefined;
            }

            if (answers.scriptName) {
                const solidityCode = fs.readFileSync(`${tooling.config.foundry.script}/${answers.scriptName}.s.sol`, "utf8");
                const regex = /function deploy\(\) public returns \((.*?)\)/;

                const matches = solidityCode.match(regex);

                if (matches && matches.length > 1) {
                    const returnValues = matches[1].trim();
                    answers.deployVariables = returnValues.split(",").map((value) => value.trim());
                    answers.deployReturnValues = returnValues.split(",").map((value) => value.trim().split(" ")[1]);
                }
            }

            if (answers.blockNumber == "latest") {
                tooling.changeNetwork(answers.network.name.toString().toLowerCase());
                answers.blockNumber = await tooling.getProvider().getBlockNumber();
                console.log(`Using Block: ${answers.blockNumber}`);
            }

            answers.blockNumber = parseInt(answers.blockNumber);
            break;
        }
        default:
            console.error(`Template ${taskArgs.template} does not exist`);
            process.exit(1);
    }

    // Compile the template
    const template = fs.readFileSync(`templates/${taskArgs.template}.hbs`, "utf8");
    const compiledTemplate = Handlebars.compile(template)(answers);
    const file = `${answers.destination}/${answers.filename}`;

    fs.writeFileSync(file, compiledTemplate);
};

const _handleScriptCauldron = async (tooling: Tooling): Promise<CauldronScriptParameters> => {
    const network = await _selectNetwork();
    const collateralName = await input({message: "Collateral name", required: true});
    let collateralAddress = tooling.getAddressByLabel(network.name, collateralName);
    let decimals: BigInt | undefined;

    if (!collateralAddress) {
        console.log(chalk.yellow(`Collateral address for ${collateralName} not found, please specify the address manually`));
        collateralAddress = await _inputAddress("Collateral Address");
    } else {
        console.log(chalk.gray(`Collateral address: ${collateralAddress}`));
    }

    const collateral = await tooling.getContractAt("IStrictERC20", collateralAddress);

    try {
        decimals = (await collateral.decimals()) as BigInt;
        console.log(chalk.gray(`Decimals: ${decimals.toString()}`));
    } catch (e) {}

    if (!decimals) {
        console.log(chalk.yellow(`Couldn't retrieve decimals for ${collateralName}, please specify manually`));
        decimals = BigInt(await input({message: "Decimals", required: true}));
    }

    return {
        collateral: {
            name: collateralName,
            address: ethers.utils.getAddress(collateralAddress),
            decimals: Number(decimals),
            aggregatorAddress: await _inputAggregator("Aggregator Address"),
        },
        parameters: {
            ltv: await _inputBipsAsPercent("LTV"),
            interests: await _inputBipsAsPercent("Interests"),
            borrowFee: await _inputBipsAsPercent("Borrow Fee"),
            liquidationFee: await _inputBipsAsPercent("Liquidation Fee"),
        },
    };
};

const _inputAddress = async (message: string): Promise<`0x${string}`> => {
    return ethers.utils.getAddress(
        await input({
            message: `${message} (0x...)`,
            validate: (value) => {
                try {
                    ethers.utils.getAddress(value);
                    return true;
                } catch (e) {
                    return false;
                }
            },
        }),
    ) as `0x${string}`;
};

const _inputAggregator = async (message: string): Promise<`0x${string}`> => {
    const address = await _inputAddress(message);

    // use IAggregator to query the chainlink oracle
    const aggregator = await tooling.getContractAt("IAggregatorWithMeta", address);

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
        console.error(`Couldn't retrieve aggregator information for ${address}`);
        console.error(e);
        process.exit(1);
    }

    return address;
};

const _inputBipsAsPercent = async (
    message: string,
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
        }),
    );

    // convert percent to bips and make sure it's an integer between 0 and 10000
    return {
        bips: Math.round(percent * 100),
        percent,
    };
};

const _selectNetwork = async (): Promise<NetworkSelection> => {
    return await select({
        message: "Network",
        choices: networks.map((network) => ({
            name: network.name,
            value: {chainId: `ChainId.${chainIdEnum[network.chainId]}`, name: network.name},
        })),
    });
};
