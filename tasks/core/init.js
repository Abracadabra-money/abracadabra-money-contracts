const repositories = require('../../libs');
const { rimraf } = require('rimraf')
const clone = require('git-clone/promise');

module.exports = async function () {
    const libs = `${hre.config.paths.root}/${hre.userConfig.foundry.libs}`;
    await rimraf(libs);

    await Promise.all(Object.keys(repositories).map(async (target) => {
        const { url, commit } = repositories[target];
        await clone(url, `${libs}/${target}`, { checkout: commit });
        await rimraf(`${libs}/${target}/.git`);
    }));
}
