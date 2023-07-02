const shell = require('shelljs');

module.exports = async function (taskArgs, hre) {
    //const networks = ["mainnet", "polygon", "moonriver", "bsc", "avalanche", "arbitrum", "fantom", "optimism", "kava"];
    const networks = ["kava"];

    // forcing solc 0.8.16 profile so that the address of the factory is the same across all chains
    shell.env["FOUNDRY_PROFILE"] = "solc_0_8_16";

    await shell.exec("yarn build");
    await hre.run("forge-deploy-multichain", { script: "Create3Factory", broadcast: false, verify: false, networks, noConfirm: true, resume: false });
}