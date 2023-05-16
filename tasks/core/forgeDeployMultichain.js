module.exports = async function (taskArgs, hre) {
    const { changeNetwork } = hre;

    for (const network of taskArgs.networks) {
        changeNetwork(network);
        
        console.log(`Deploying to ${network}...`);
        await hre.run("forge-deploy", { network, script: taskArgs.script, broadcast: taskArgs.broadcast, verify: taskArgs.verify, noConfirm: taskArgs.noConfirm });
    }
}