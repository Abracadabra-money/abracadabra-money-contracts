const inquirer = require('inquirer');
const Handlebars = require('handlebars');
const fs = require('fs');
const shell = require('shelljs');
const {
  glob
} = require('glob');

module.exports = async function (taskArgs, hre) {
  const { getChainIdByNetworkName, userConfig } = hre;
  const networks = Object.keys(userConfig.networks).map(network => ({ name: network, chainId: userConfig.networks[network].chainId }));

  const chainIdEnum = {
    1: "Mainnet",
    56: "BSC",
    137: "Polygon",
    250: "Fantom",
    10: "Optimism",
    42161: "Arbitrum",
    43114: "Avalanche",
    1285: "Moonriver"
  };

  let answers = {};

  const desinationFolders = [...await glob(`${hre.userConfig.foundry.src}/**/`, { nodir: false, ignore: "**/compat" }),
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
          default: answers => `${answers.scriptName}.s.sol`
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
          default: answers => `${answers.contractName}.sol`
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
      answers = await inquirer.prompt([
        { name: 'testName', message: 'Test Name' },
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
      answers.scriptName = answers.testName;
      answers.destination = hre.userConfig.foundry.test;

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

