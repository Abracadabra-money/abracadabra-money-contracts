const { libs } = require('../../package.json');
const shell = require('shelljs');
const { access, constants } = require('node:fs/promises');

const libDir = `${__dirname}/../../lib`;

module.exports = async function () {
    if(process.env.SKIP_INTEGRITY_CHECK) {
        console.log("Skipping integrity check...");
        return;
    }
    await Promise.all(Object.keys(libs).map(async (target) => {
        const { commit } = libs[target];

        const dest = `${libDir}/${target}`;

        try {
            await access(dest, constants.R_OK);
        } catch {
            return;
        }

        // check commit hash
        let response = await shell.exec(`(cd ${dest} && git rev-parse HEAD)`, { silent: true, fatal: false });
        if (response.stdout.toString().trim() == commit) {
            // check if there are changes
            response = await shell.exec(`(cd ${dest} && git status --porcelain)`, { silent: true, fatal: false });
            if (response.stdout.length != 0) {
                console.log(`❌ ${target} integrity check failed, changes detected. Revert changes or run yarn again.`);
                process.exit(1);
            }
        } else {
            console.log(`❌ ${target} version mismatch, run yarn again.`);
            process.exit(1);
        }
    }));
}