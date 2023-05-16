const shell = require('shelljs');

module.exports = async function (taskArgs, hre) {
    let result = await shell.exec(`grep -rlw --max-count=1 --include=\*.sol '${taskArgs.path}' -e 'console\.sol'; grep -rlw --max-count=1 --include=\*.sol '${taskArgs.path}' -e 'console2\.sol'`, { silent: true });

    if(result.stdout) {
        console.error(`Found console log import in ${result.stdout}`);
        process.exit(1);
    }
}