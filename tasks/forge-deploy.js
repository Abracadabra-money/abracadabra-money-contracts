const fs = require('fs');
const shell = require('shelljs');

module.exports = async function (taskArgs, hre) {
    console.log(`Using network ${hre.network.name}`);
    
    const foundry = hre.userConfig.foundry;
    await hre.run("check-console-log", { path: foundry.src });

    const apiKey = hre.network.config.api_key;

    let broadcast_args = "";
    let verify_args = "";
    let resume_args = "";

    if (taskArgs.resume) {
        resume_args = "--resume";
    } else if (taskArgs.broadcast) {
        broadcast_args = "--broadcast";
    }

    if (taskArgs.verify) {
        verify_args = `--verify --etherscan-api-key ${apiKey}`;
    }

    let script = `${foundry.script}/${taskArgs.script}.s.sol`;

    if (!fs.existsSync(script)) {
        console.error(`Script ${script} does not exist`);
        process.exit(1);
    }

    const output = await shell.exec(`forge script ${script} --rpc-url ${hre.network.config.url} --private-key ${process.env.PRIVATE_KEY} ${broadcast_args} ${verify_args} ${resume_args} -vvvv`, { silent: true });
    console.log(output.stdout);

    await shell.exec("forge-deploy sync");
}