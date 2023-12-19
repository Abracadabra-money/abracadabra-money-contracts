const inquirer = require('inquirer');
const Handlebars = require('handlebars');
const fs = require('fs');
const path = require('path');
const shell = require('shelljs');
const {
  glob
} = require('glob');

module.exports = async function (taskArgs, hre) {
  const { userConfig } = hre;
  const networks = Object.keys(userConfig.networks).map(network => ({ name: network, chainId: userConfig.networks[network].chainId }));
  const chainIdEnum = Object.keys(userConfig.networks).reduce((acc, network) => {
    const capitalizedNetwork = network.charAt(0).toUpperCase() + network.slice(1);
    return { ...acc, [userConfig.networks[network].chainId]: capitalizedNetwork };
  }, {});

  let answers = {};

  const desinationFolders = [...await glob(`${hre.userConfig.foundry.src}/**/`, { nodir: false }),
  ...await glob(`${hre.userConfig.foundry.src}/../utils/**/`, { nodir: false })]

  const defaultPostDefaultQuestions = [
    {
      message: 'Destination Folder',
      type: 'list',
      name: 'destination',
      choices: desinationFolders.map(folder => folder)
    },
  ];

  switch (taskArgs.template) {
    case 'script':
      answers = await inquirer.prompt([
        { name: 'scriptName', message: 'Script Name' },
        {
          name: 'filename',
          message: 'Filename',
          default: answers => `${answers.scriptName}.s.sol`,
        }
      ]);
      answers.destination = hre.userConfig.foundry.script;
      break;
    case 'interface':
      answers = await inquirer.prompt([
        { name: 'interfaceName', message: 'Interface Name' },
        {
          name: 'filename',
          message: 'Filename',
          default: answers => `${answers.interfaceName}.sol`
        }
      ]);
      answers.destination = `${hre.userConfig.foundry.src}/interfaces`;
      break;
    case 'contract':
      answers = await inquirer.prompt([
        { name: 'contractName', message: 'Contract Name' },
        {
          name: 'filename',
          message: 'Filename',
          default: answers => `${answers.contractName}.sol`
        },
        {
          name: 'operatable', type: 'confirm',
          message: 'Operatable?',
          default: false
        },
        ...defaultPostDefaultQuestions
      ]);
      break;
    case 'test':
      const scriptFiles = (await glob(`${hre.userConfig.foundry.script}/*.s.sol`)).map(f => path.basename(f).replace(".s.sol", ""));
      const modes = [{
        name: "Simple",
        value: "simple"
      },
      {
        name: "Multi (base test-contract + per-suite-test-contract)",
        value: "multi"
      }];

      answers = await inquirer.prompt([
        { name: 'testName', message: 'Test Name' },
        {
          message: 'Script',
          type: 'list',
          name: 'scriptName',
          choices: ["(None)", ...scriptFiles],
          default: answers => answers.testName
        },
        {
          message: 'Type',
          type: 'list',
          name: 'mode',
          choices: modes
        },
        {
          message: 'Network',
          type: 'list',
          name: 'network',
          choices: networks.map(network => ({ name: network.name, value: { chainId: `ChainId.${chainIdEnum[network.chainId]}`, name: network.name } }))
        },
        { name: 'blockNumber', message: 'Block', default: "latest" },
        {
          name: 'filename',
          message: 'Filename',
          default: answers => `${answers.testName}.t.sol`
        }
      ]);
      answers.destination = hre.userConfig.foundry.test;

      if (answers.mode === "multi") {
        taskArgs.template = "test-multi";
      }

      if (answers.scriptName === "(None)") {
        answers.scriptName = undefined;
      }

      if (answers.scriptName) {
        const solidityCode = fs.readFileSync(`${hre.userConfig.foundry.script}/${answers.scriptName}.s.sol`, 'utf8');
        const regex = /function deploy\(\) public returns \((.*?)\)/;

        const matches = solidityCode.match(regex);

        if (matches && matches.length > 1) {
          const returnValues = matches[1].trim();
          answers.deployVariables = returnValues.split(',').map(value => value.trim());
          answers.deployReturnValues = returnValues.split(',').map(value => value.trim().split(' ')[1]);
        }
      }

      if (answers.blockNumber == "latest") {
        changeNetwork(answers.network.name.toString().toLowerCase());
        answers.blockNumber = await hre.ethers.provider.getBlockNumber();
        console.log(`Using Block: ${answers.blockNumber}`);
      }

      answers.blockNumber = parseInt(answers.blockNumber);
      break;
    default:
      console.error(`Template ${taskArgs.template} does not exist`);
      process.exit(1);
  }

  // Compile the template
  const template = fs.readFileSync(`templates/${taskArgs.template}.hbs`, 'utf8');
  const compiledTemplate = Handlebars.compile(template)(answers);
  const file = `${answers.destination}/${answers.filename}`;

  fs.writeFileSync(file, compiledTemplate);
  await shell.exec(`npx prettier --write ${file}`, { silent: true });
};

