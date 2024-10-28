import {
    CollateralType,
    NetworkName,
    type BipsPercent,
    type NamedAddress,
    type TaskArgs,
    type TaskFunction,
    type TaskMeta,
} from "../../types";
import path from "path";
import fs from "fs";
import {formatDecimals, getERC20Meta} from "../utils";
import {input, confirm, number} from "@inquirer/prompts";
import select from "@inquirer/select";
import Handlebars from "handlebars";
import {$} from "bun";
import chalk from "chalk";
import {rm} from "fs/promises";
import {type Tooling} from "../../tooling";
import * as inputs from "../utils/inputs";
import {parse, visit} from "@solidity-parser/parser";

export const meta: TaskMeta = {
    name: "gen/gen",
    description: "Generate a script, interface, contract, test, cauldron deployment",
    options: {},
    positionals: {
        name: "template",
        description: "Template to generate",
        required: true,
        choices: ["script", "script:cauldron", "interface", "contract", "contract:magic-vault", "contract:upgradeable", "test"],
        maxPostionalCount: 1,
    },
};

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

let tooling: Tooling;

export const task: TaskFunction = async (taskArgs: TaskArgs, _tooling: Tooling) => {
    await $`bun run build`;

    tooling = _tooling;

    await inputs.init();

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
            const destination = await inputs.selectDestinationFolder();

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
            const destination = await inputs.selectDestinationFolder();

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
            const destination = await inputs.selectDestinationFolder("src", "src/tokens");
            const network = await inputs.selectNetwork();
            const useDynamicName = await confirm({message: "Use Dynamic Name?", default: false});
            const asset = await inputs.selectToken("Underlying Asset", network.name);
            const staking = await inputs.inputAddress(network.name, "Staking", false);

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
            const destination = await inputs.selectDestinationFolder();

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
            const scriptName = await inputs.selectScript(testName);

            const mode = await select({
                message: "Type",
                choices: modes,
            });
            const network = await inputs.selectNetwork();
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
        default:
            console.error(`Template ${taskArgs.template} does not exist`);
            process.exit(1);
    }
};

const _writeTemplate = (templateName: string, destinationFolder: string, fileName: string, templateData: any): string => {
    const template = fs.readFileSync(`templates/${templateName}.hbs`, "utf8");

    const compiledTemplate = Handlebars.compile(template)(templateData);
    const file = `${destinationFolder}/${fileName}`;

    fs.writeFileSync(file, compiledTemplate);

    return file;
};

const _handleScriptCauldron = async (tooling: Tooling): Promise<CauldronScriptParameters> => {
    const network = await inputs.selectNetwork();
    const collateralNamedAddress = await inputs.inputAddress(network.name, "Collateral");
    const assetInfo = await getERC20Meta(tooling, collateralNamedAddress.address);

    console.log(chalk.gray(`${assetInfo.name} [${assetInfo.symbol}]`));
    console.log(chalk.gray(`Decimals: ${assetInfo.decimals}`));

    const collateralType = await inputs.selectCollateralType();
    let aggregatorNamedAddress: NamedAddress;

    switch (collateralType) {
        case CollateralType.ERC20:
            aggregatorNamedAddress = await inputs.inputAggregator(network.name, `${assetInfo.name}[${assetInfo.symbol}] Aggregator Address`);
            break;
        case CollateralType.ERC4626:
            const erc4626Collateral = await tooling.getContractAt("IERC4626", collateralNamedAddress.address);
            try {
                const underlyingAssetInfo = await getERC20Meta(tooling, await erc4626Collateral.asset());
                aggregatorNamedAddress = await inputs.inputAggregator(network.name, `${underlyingAssetInfo.name}[${underlyingAssetInfo.symbol}] Aggregator Address`);
            } catch (e) {
                console.error("Couldn't retrieve underlying asset information for ERC4626 collateral");
                process.exit(1);
            }
            break;
        case CollateralType.UNISWAPV3_LP:
            console.log(chalk.yellow("Uniswap V3 LP collateral type is not supported yet"));
            process.exit(1);
    }

    return {
        collateral: {
            namedAddress: collateralNamedAddress,
            decimals: Number(assetInfo.decimals),
            aggregatorNamedAddress,
            type: collateralType,
        },
        parameters: {
            ltv: await inputs.inputBipsAsPercent("LTV"),
            interests: await inputs.inputBipsAsPercent("Interests"),
            borrowFee: await inputs.inputBipsAsPercent("Borrow Fee"),
            liquidationFee: await inputs.inputBipsAsPercent("Liquidation Fee"),
        },
    };
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
