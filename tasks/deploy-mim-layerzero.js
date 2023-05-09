module.exports = async function (taskArgs, hre) {
    const { foundryDeployments, changeNetwork } = hre;

    await hre.run("forge-deploy-multichain", { script: "MIMLayerZero", broadcast: taskArgs.broadcast, verify: taskArgs.verify, networks: ["mainnet", "arbitrum"] });
    /*
    
        // doing on a second step as a demonstration
        for (const network of taskArgs.networks) {
            changeNetwork(network);
    
            const TestContract = await foundryDeployments.get("TestContract"); // get thru foundry deployments
            await TestContract.setParam(`hello ${network} 1`);
    
            const TestContract2 = await ethers.getContractAt("TestContract", TestContract.address); // get thru hardhat artifacts
            await TestContract2.setParam(`hello ${network} 2`);
        }
        */
}