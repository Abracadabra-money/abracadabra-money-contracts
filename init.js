const { libs } = require('./package.json');
const { rimraf } = require('rimraf')
const clone = require('git-clone/promise');

const destination = process.argv[2];

(async () => {
    await rimraf(destination);

    await Promise.all(Object.keys(libs).map(async (target) => {
        const { url, commit } = libs[target];
        await clone(url, `${destination}/${target}`, { checkout: commit });
        await rimraf(`${destination}/${target}/.git`);
    }));
})();


