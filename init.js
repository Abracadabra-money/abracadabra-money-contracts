const { libs } = require('./package.json');
const { rimraf } = require('rimraf')
const shell = require('shelljs');

const destination = process.argv[2];

(async () => {
    await rimraf(destination);

    await Promise.all(Object.keys(libs).map(async (target) => {
        const { url, commit } = libs[target];
        console.log(`✨Installing ${target} from ${url} at ${commit}`);
        await shell.exec(`git clone --recurse-submodules ${url} ${destination}/${target}`, { silent: true, fatal: true, });
        await shell.exec(`git checkout ${commit}`, { silent: true, fatal: true, cwd: `${destination}/${target}` });
        await rimraf(`${destination}/${target}/**/.git`);
    }));
})();


