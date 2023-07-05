const shell = require('shelljs');

module.exports = async function (taskArgs, hre) {
    const networks = ["mainnet", "polygon", "moonriver", "bsc", "avalanche", "arbitrum", "fantom", "optimism", "kava"];

    await shell.exec("yarn build");
    await hre.run("forge-deploy-multichain", { script: "Create3Factory", broadcast: true, verify: true, networks, noConfirm: true, resume: false });
}