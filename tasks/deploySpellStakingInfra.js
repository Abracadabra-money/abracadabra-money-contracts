const shell = require('shelljs');

module.exports = async function (taskArgs, hre) {
    const { foundryDeployments } = hre;

    await shell.exec("yarn build");
    await hre.run("forge-deploy-multichain", { script: "SpellStakingRewardInfra", broadcast: taskArgs.broadcast, verify: taskArgs.verify, networks: ["mainnet"], noConfirm: taskArgs.noConfirm, resume: taskArgs.resume });

    const networks = ["avalanche", "arbitrum", "fantom"];
    let mainnetDistributor = hre.ethers.constants.AddressZero;

    if (foundryDeployments.deploymentExists("Mainnet_SpellStakingRewardDistributor", 1)) {
        mainnetDistributor = (await foundryDeployments.getDeployment("Mainnet_SpellStakingRewardDistributor", 1)).address;
    }

    shell.env["MAINNET_DISTRIBUTOR"] = mainnetDistributor;
    await hre.run("forge-deploy-multichain", { script: "SpellStakingRewardInfra", broadcast: taskArgs.broadcast, verify: taskArgs.verify, networks, noConfirm: taskArgs.noConfirm, resume: taskArgs.resume });

    // TODO: For each chain, generate tx gnosis safe transaction batch for necessary operations
    // - loop thru added cauldrons for each withdrawer and check if owner is ops safe
    // - change master contract feeTo to withdrawer when required
    // - rescue tokens from existing withdrawer to new withdrawers, on mainnet transfer to distributor directly
}