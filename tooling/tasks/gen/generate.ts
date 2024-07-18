import type { TaskArgs, TaskFunction, TaskMeta, Tooling } from '../../types';
import path from 'path';
import fs from 'fs';
import { getFolders } from '../utils';
import { input } from '@inquirer/prompts';
import Handlebars from 'handlebars';

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
    }, {});

    let answers: any = {};

    const srcFolder = path.join(tooling.config.foundry.src);
    const utilsFolder = path.join('utils');

    const destinationFolders = [
        ...await getFolders(srcFolder),
        ...await getFolders(utilsFolder)
    ];

    const defaultPostDefaultQuestions = [
        {
            message: 'Destination Folder',
            type: 'list',
            name: 'destination',
            choices: destinationFolders.map(folder => folder)
        },
    ];

    switch ((taskArgs.template as string[])[0] as string) {
        case 'script':
            const scriptName = await input({ message: 'Script Name' });
            const filename = await input({ message: 'Filename', default: `${scriptName}.s.sol` });

            answers.scriptName = scriptName;
            answers.filename = filename
            answers.destination = tooling.config.foundry.script;
            break;
        //case 'interface':
        //    answers = await inquirer.prompt([
        //        { name: 'interfaceName', message: 'Interface Name' },
        //        {
        //            name: 'filename',
        //            message: 'Filename',
        //            default: answers => `${answers.interfaceName}.sol`
        //        }
        //    ]);
        //    answers.destination = `${tooling.config.foundry.src}/interfaces`;
        //    break;
        //case 'contract':
        //    answers = await inquirer.prompt([
        //        { name: 'contractName', message: 'Contract Name' },
        //        {
        //            name: 'filename',
        //            message: 'Filename',
        //            default: answers => `${answers.contractName}.sol`
        //        },
        //        {
        //            name: 'operatable', type: 'confirm',
        //            message: 'Operatable?',
        //            default: false
        //        },
        //        ...defaultPostDefaultQuestions
        //    ]);
        //    break;
        //case 'blast-wrapped':
        //    answers = await inquirer.prompt([
        //        { name: 'contractName', message: 'Contract Name' },
        //        {
        //            name: 'filename',
        //            message: 'Filename',
        //            default: answers => `${answers.contractName}.sol`
        //        },
        //        ...defaultPostDefaultQuestions
        //    ]);
        //    break;

        //case 'test':
        //    const scriptFiles = (await glob(`${tooling.config.foundry.script}/*.s.sol`)).map(f => path.basename(f).replace(".s.sol", ""));
        //    const modes = [{
        //        name: "Simple",
        //        value: "simple"
        //    },
        //    {
        //        name: "Multi (base test-contract + per-suite-test-contract)",
        //        value: "multi"
        //    }];

        //    answers = await inquirer.prompt([
        //        { name: 'testName', message: 'Test Name' },
        //        {
        //            message: 'Script',
        //            type: 'list',
        //            name: 'scriptName',
        //            choices: ["(None)", ...scriptFiles],
        //            default: answers => answers.testName
        //        },
        //        {
        //            message: 'Type',
        //            type: 'list',
        //            name: 'mode',
        //            choices: modes
        //        },
        //        {
        //            message: 'Network',
        //            type: 'list',
        //            name: 'network',
        //            choices: networks.map(network => ({ name: network.name, value: { chainId: `ChainId.${chainIdEnum[network.chainId]}`, name: network.name } }))
        //        },
        //        { name: 'blockNumber', message: 'Block', default: "latest" },
        //        {
        //            name: 'filename',
        //            message: 'Filename',
        //            default: answers => `${answers.testName}.t.sol`
        //        }
        //    ]);
        //    answers.destination = tooling.config.foundry.test;

        //    if (answers.mode === "multi") {
        //        taskArgs.template = "test-multi";
        //    }

        //    if (answers.scriptName === "(None)") {
        //        answers.scriptName = undefined;
        //    }

        //    if (answers.scriptName) {
        //        const solidityCode = fs.readFileSync(`${tooling.config.foundry.script}/${answers.scriptName}.s.sol`, 'utf8');
        //        const regex = /function deploy\(\) public returns \((.*?)\)/;

        //        const matches = solidityCode.match(regex);

        //        if (matches && matches.length > 1) {
        //            const returnValues = matches[1].trim();
        //            answers.deployVariables = returnValues.split(',').map(value => value.trim());
        //            answers.deployReturnValues = returnValues.split(',').map(value => value.trim().split(' ')[1]);
        //        }
        //    }

        //    if (answers.blockNumber == "latest") {
        //        tooling.changeNetwork(answers.network.name.toString().toLowerCase());
        //        answers.blockNumber = await tooling.getProvider().getBlockNumber();
        //        console.log(`Using Block: ${answers.blockNumber}`);
        //    }

        //    answers.blockNumber = parseInt(answers.blockNumber);
        //    break;
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

