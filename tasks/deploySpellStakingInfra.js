const shell = require('shelljs');

module.exports = async function (taskArgs, hre) {
    const { foundryDeployments } = hre;

    await shell.exec("yarn build");
    await hre.run("forge-deploy-multichain", { script: "SpellStakingRewardInfra", broadcast: taskArgs.broadcast, verify: taskArgs.verify, networks: ["mainnet"], noConfirm: taskArgs.noConfirm });

    const networks = ["avalanche", "arbitrum", "fantom"];
    let mainnetDistributor = hre.ethers.constants.AddressZero;

    if (foundryDeployments.deploymentExists("Mainnet_SpellStakingRewardDistributor", 1)) {
        mainnetDistributor = (await foundryDeployments.getDeployment("Mainnet_SpellStakingRewardDistributor", 1)).address;
    } else {
        console.error("Mainnet_SpellStakingRewardDistributor deployment not found");
        process.exit(1);
    }

    shell.env["MAINNET_DISTRIBUTOR"] = mainnetDistributor;
    await hre.run("forge-deploy-multichain", { script: "SpellStakingRewardInfra", broadcast: taskArgs.broadcast, verify: taskArgs.verify, networks, noConfirm: taskArgs.noConfirm });
}