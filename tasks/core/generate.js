const inquirer = require('inquirer');
const Handlebars = require('handlebars');
const fs = require('fs');
const shell = require('shelljs');
const {
  glob
} = require('glob');

module.exports = async function (taskArgs, hre) {
  let answers = {};

  const desinationFolders = [...await glob(`${hre.userConfig.foundry.src}/**/`, { nodir: false, ignore: "**/compat" }),
  ...await glob(`${hre.userConfig.foundry.src}/../utils/**/`, { nodir: false })]

  const defaultPreDefaultQuestions = [
    { name: 'contractName', message: 'Contract Name' },
    {
      name: 'filename',
      message: 'Filename',
      default: answers => `${answers.contractName}.sol`
    },
  ];

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
        ...defaultPreDefaultQuestions
      ]);
      answers.destination = `${hre.userConfig.foundry.src}/interfaces`;
      break;
    case 'contract':
      answers = await inquirer.prompt([
        ...defaultPreDefaultQuestions,
        {
          name: 'operatable', type: 'confirm',
          message: 'Operatable?',
          default: false
        },
        ...defaultPostDefaultQuestions
      ]);
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

