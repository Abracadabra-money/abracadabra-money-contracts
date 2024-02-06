const { libs } = require('./package.json');
const { rimraf } = require('rimraf')
const shell = require('shelljs');
const { readdir, constants } = require('node:fs/promises');

const destination = `${__dirname}/lib`;
(async () => {
    // delete all folder not in libs
    try {
        await Promise.all((await readdir(destination)).map(async (folder) => {
            if (!libs[folder]) {
                await rimraf(`${destination}/${folder}`);
            }
        }));
    } catch { }

    const keys = Object.keys(libs);
    for (let i = 0; i < keys.length; i++) {
        const target = keys[i];
        const { url, commit } = libs[target];
        const dest = `${destination}/${target}`;

        let installed = false;

        // check commit hash
        try {
            let response = await shell.exec(`(cd ${dest} && git rev-parse HEAD)`, { silent: true, fatal: false });
            if (response.stdout.toString().trim() == commit) {
                // check if there are changes
                response = await shell.exec(`(cd ${dest} && git status --porcelain)`, { silent: true, fatal: false });
                installed = response.stdout.length == 0;
            }
        } catch { }

        if (installed) {
            console.log(`✨ ${target} already installed`);
            continue;
        }

        await rimraf(dest);

        console.log(`✨ Installing ${url}#${commit} to ${target}`);
        await shell.exec(`git clone --recurse-submodules ${url} ${dest}`, { silent: true, fatal: true, });

        if (await shell.exec(`(cd ${dest} && git cat-file -t ${commit})`, { silent: true, fatal: false }).stdout.trim() != 'commit') {
            console.log(`❌ ${target}, commit ${commit} not found.`);
            process.exit(1);
        }

        await shell.exec(`(cd ${dest} && git checkout ${commit})`, { silent: true, fatal: true });
        await shell.exec(`(cd ${dest} && git submodule update --init --recursive)`, { silent: true, fatal: true });
    };
})();
