const fs = require('fs');
const inquirer = require('inquirer');
const shell = require('shelljs');

module.exports = async function (taskArgs, hre) {
    let broadcast_args = "";
    let verify_args = "";
    let resume_args = "";
    let env_args = "";
    let anvilProcessId;

    if (hre.network.name === "localhost") {
        env_args = "DEPLOYMENT_CONTEXT=localhost";
        taskArgs.verify = false;

        console.log("Starting Anvil...");
        anvilProcessId = shell.exec('killall -9 anvil; anvil > /dev/null 2>&1 & echo $!', { silent: true, fatal: true }).stdout.trim();
    }

    console.log(`Using network ${hre.network.name}`);

    const foundry = hre.userConfig.foundry;
    await hre.run("check-console-log", { path: foundry.src });

    const apiKey = hre.network.config.api_key;

    if (taskArgs.resume) {
        taskArgs.broadcast = false;
        resume_args = "--resume";
    } else if (taskArgs.broadcast) {
        taskArgs.resume = false;
        broadcast_args = "--broadcast";

        if (!taskArgs.noConfirm) {
            const answers = await inquirer.prompt([
                {
                    name: 'confirm',
                    type: 'confirm',
                    default: false,
                    message: `This is going to: \n\n- Deploy contracts to ${hre.network.name} ${taskArgs.verify ? "\n- Verify contracts" : "\n- Leave the contracts unverified"} \n\nAre you sure?`,
                }
            ]);

            if (answers.confirm === false) {
                process.exit(0);
            }
        }
    }

    if (taskArgs.verify) {
        verify_args = `--verify --etherscan-api-key ${apiKey}`;
    }

    let script = `${foundry.script}/${taskArgs.script}.s.sol`;

    if (!fs.existsSync(script)) {
        console.error(`Script ${script} does not exist`);
        process.exit(1);
    }

    const cmd = `${env_args} forge script ${script} --rpc-url ${hre.network.config.url} ${broadcast_args} ${verify_args} ${resume_args} -vvvv --private-key *******`.replace(/\s+/g, ' ');
    console.log(cmd);

    const result = await shell.exec(cmd.replace('*******', process.env.PRIVATE_KEY), { fatal: false });
    await shell.exec("./forge-deploy sync", { silent: true });

    if (result.code != 0) {
        process.exit(result.code);
    }

    if (anvilProcessId) {
        console.log("Stopping Anvil...");
        await shell.exec(`kill ${anvilProcessId}`, { silent: true });
    }
}