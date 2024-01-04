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
    let live = false

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

        live = true;
        await shell.exec(`rm -rf ${foundry.broadcast}`, { silent: true });
    }

    if (taskArgs.verify) {
        if (apiKey) {
            verify_args = `--verify --etherscan-api-key ${apiKey}`;
        } else {
            const answers = await inquirer.prompt([
                {
                    name: 'confirm',
                    type: 'confirm',
                    default: false,
                    message: `You are trying to verify contracts on ${hre.network.name} without an etherscan api key. \n\nAre you sure?`
                }
            ]);

            if (answers.confirm === false) {
                process.exit(0);
            }

            verify_args = `--verify`;
        }
    }

    let script = `${foundry.script}/${taskArgs.script}.s.sol`;

    if (!fs.existsSync(script)) {
        // check if a shanghai script exists
        script = `${foundry.script}/${taskArgs.script}.s.shanghai.sol`;
        if (fs.existsSync(script)) {
            env_args = `${env_args} FOUNDRY_PROFILE=shanghai`;
        } else {
            console.error(`Script ${taskArgs.script} does not exist`);
            process.exit(1);
        }
    }

    cmd = `${env_args} forge script ${script} --rpc-url ${hre.network.config.url} ${broadcast_args} ${verify_args} ${resume_args} ${taskArgs.extra || ""} ${hre.network.config.forgeDeployExtraArgs || ""} --slow --private-key *******`.replace(/\s+/g, ' ');
    console.log(cmd);
    result = await shell.exec(cmd.replace('*******', process.env.PRIVATE_KEY), { fatal: false });
    await shell.exec("./forge-deploy sync", { silent: true });

    if (result.code != 0) {
        process.exit(result.code);
    }

    if (anvilProcessId) {
        console.log("Stopping Anvil...");
        await shell.exec(`kill ${anvilProcessId}`, { silent: true });
    }
}
