const { task } = require("hardhat/config");

module.exports = async function (taskArgs, hre) {
    const { changeNetwork } = hre;

    if (taskArgs.networks.length == 1 && taskArgs.networks[0] == "all") {
        taskArgs.networks = hre.getAllNetworks();
    }

    for (const network of taskArgs.networks) {
        changeNetwork(network);
        
        console.log(`Deploying to ${network}...`);
        await hre.run("forge-deploy", { network, script: taskArgs.script, broadcast: taskArgs.broadcast, verify: taskArgs.verify, noConfirm: taskArgs.noConfirm, resume: taskArgs.resume });
    }
}