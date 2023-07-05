const { libs } = require('./package.json');
const { rimraf } = require('rimraf')
const shell = require('shelljs');
const { access, open, readdir, constants } = require('node:fs/promises');

const destination = process.argv[2];

(async () => {
    // delete all folder not in libs
    await Promise.all((await readdir(destination)).map(async (folder) => {
        if (!libs[folder]) {
            await rimraf(`${destination}/${folder}`);
        }
    }));

    await Promise.all(Object.keys(libs).map(async (target) => {
        const { url, commit } = libs[target];

        const dotHashfile = `${destination}/${target}/.${commit}`;
        try {
            if (await access(dotHashfile), constants.R_OK) {
                console.log(`✨${target} already installed`);
                return;
            }
        } catch { }

        const dest = `${destination}/${target}`;
        await rimraf(dest);

        console.log(`✨ Installing ${url}#${commit} to ${target}`);
        await shell.exec(`git clone --recurse-submodules ${url} ${dest}`, { silent: true, fatal: true, });
        await shell.exec(`git checkout ${commit}`, { silent: true, fatal: true, cwd: `${dest}` });
        await rimraf(`${dest}/**/.git`);

        await (await open(dotHashfile, 'a')).close();
    }));
})();