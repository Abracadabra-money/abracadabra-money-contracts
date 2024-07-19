import type { TaskArgs, TaskFunction, TaskMeta, Tooling } from '../../types';
import path from 'path';
import fs from 'fs';
import { getFolders } from '../utils';
import { input, confirm } from '@inquirer/prompts';
import select from '@inquirer/select';
import Handlebars from 'handlebars';
import { Glob } from 'bun';

export const meta: TaskMeta = {
    name: 'gen:gen',
    description: 'Generate a script, interface, contract or test',
    options: {},
    positionals: {
        name: 'template',
        description: 'Template to generate [script, interface, contract, test]',
        required: true
    }
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const networks = Object.keys(tooling.config.networks).map(network => ({ name: network, chainId: tooling.config.networks[network].chainId }));
    const chainIdEnum = Object.keys(tooling.config.networks).reduce((acc, network) => {
        const capitalizedNetwork = network.charAt(0).toUpperCase() + network.slice(1);
        return { ...acc, [tooling.config.networks[network].chainId]: capitalizedNetwork };
    }, {}) as { [key: string]: string };

    let answers: any = {};

    const srcFolder = path.join(tooling.config.foundry.src);
    const utilsFolder = path.join('utils');

    const destinationFolders = [
        ...await getFolders(srcFolder),
        ...await getFolders(utilsFolder)
    ];

    const glob = new Glob("*.s.sol");
    const scriptFiles = (await Array.fromAsync(glob.scan(tooling.config.foundry.script))).map(f => {
        const name = path.basename(f).replace(".s.sol", "")
        return {
            name,
            value: name
        }
    });

    const promptDestinationFolder = async () => {
        return await select({
            message: 'Destination Folder',
            choices: destinationFolders.map(folder => ({ name: folder, value: folder }))
        });
    }

    taskArgs.template = (taskArgs.template as string[])[0] as string;

    switch (taskArgs.template) {
        case 'script': {
            const scriptName = await input({ message: 'Script Name' });
            const filename = await input({ message: 'Filename', default: `${scriptName}.s.sol` });

            answers.scriptName = scriptName;
            answers.filename = filename
            answers.destination = tooling.config.foundry.script;
            break;
        }
        case 'interface': {
            const interfaceName = await input({ message: 'Interface Name' });
            const filename = await input({ message: 'Filename', default: `${interfaceName}.sol` });

            answers.interfaceName = interfaceName;
            answers.filename = filename
            answers.destination = `${tooling.config.foundry.src}/interfaces`;
            break;
        }
        case 'contract': {
            const contractName = await input({ message: 'Contract Name' });
            const filename = await input({ message: 'Filename', default: `${contractName}.sol` });
            const operatable = await confirm({ message: 'Operatable?', default: false });
            const destination = await promptDestinationFolder();

            answers.contractName = contractName;
            answers.filename = filename
            answers.destination = destination;
            answers.operatable = operatable;
            break;
        }
        case 'blast-wrapped': {
            const contractName = await input({ message: 'Contract Name' });
            const filename = await input({ message: 'Filename', default: `${contractName}.sol` });
            const destination = await promptDestinationFolder();
            answers.contractName = contractName;
            answers.filename = filename
            answers.destination = destination;
            break;
        }
        case 'test': {
            const modes = [{
                name: "Simple",
                value: "simple"
            },
            {
                name: "Multi (base test-contract + per-suite-test-contract)",
                value: "multi"
            }];

            const testName = await input({ message: 'Test Name' });
            const scriptName = await select({
                message: 'Script',
                choices: [{ name: "(None)", value: "(None)" }, ...scriptFiles],
                default: testName
            });
            const mode = await select({
                message: 'Type',
                choices: modes
            });
            const network = await select({
                message: 'Network',
                choices: networks.map(network => ({ name: network.name, value: { chainId: `ChainId.${chainIdEnum[network.chainId]}`, name: network.name } }))
            });
            const blockNumber = await input({ message: 'Block', default: "latest" });
            const filename = await input({ message: 'Filename', default: `${testName}.t.sol` });

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
                const solidityCode = fs.readFileSync(`${tooling.config.foundry.script}/${answers.scriptName}.s.sol`, 'utf8');
                const regex = /function deploy\(\) public returns \((.*?)\)/;

                const matches = solidityCode.match(regex);

                if (matches && matches.length > 1) {
                    const returnValues = matches[1].trim();
                    answers.deployVariables = returnValues.split(',').map(value => value.trim());
                    answers.deployReturnValues = returnValues.split(',').map(value => value.trim().split(' ')[1]);
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
    const template = fs.readFileSync(`templates/${taskArgs.template}.hbs`, 'utf8');
    const compiledTemplate = Handlebars.compile(template)(answers);
    const file = `${answers.destination}/${answers.filename}`;

    fs.writeFileSync(file, compiledTemplate);
};

