const { libs } = require('../../package.json');
const shell = require('shelljs');
const { access, constants } = require('node:fs/promises');

const libDir = `${__dirname}/../../lib`;

module.exports = async function () {
    await Promise.all(Object.keys(libs).map(async (target) => {

        const dest = `${libDir}/${target}`;

        try {
            await access(dest, constants.R_OK);
        } catch {
            return;
        }

        const response = await shell.exec(`(cd ${dest} && git status --porcelain --untracked-files=no)`, { silent: true, fatal: true });
        if (response.stdout.length > 0) {
            console.log(`❌ ${target} integrity check failed, changes detected. Revert changes or run yarn again.`);
            process.exit(1);
        }
    }));
}