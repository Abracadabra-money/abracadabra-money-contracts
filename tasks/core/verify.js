const shell = require('shelljs');

// usage example:
// yarn task verify --network base --deployment Base_Create3Factory --artifact src/mixins/Create3Factory.sol:Create3Factory
// use --show-standard-json-input to get the json input to manually verify on etherscan
module.exports = async function (taskArgs, hre) {
    const { getChainIdByNetworkName, getDeployment, getArtifact } = hre;

    const apiKey = hre.network.config.api_key;
    const forgeVerifyExtraArgs = hre.network.config.forgeVerifyExtraArgs;
    const chainId = getChainIdByNetworkName(hre.network.name);
    const deployment = await getDeployment(taskArgs.deployment, chainId);
    const address = deployment.address;
    const constructorArgs = deployment.args_data;
    const artifact = await getArtifact(taskArgs.artifact);
    const numOfOptimizations = artifact.metadata.settings.optimizer.runs;
    const compiler = artifact.metadata.compiler.version;

    let args = "";
    if (apiKey) {
        args = `-e ${apiKey} ${forgeVerifyExtraArgs || ""}`;
    } else {
        args = forgeVerifyExtraArgs || "";
    }

    if(taskArgs.showStandardJsonInput) {
        args = `${args} --show-standard-json-input > standard-json-input.json`;
    }

    const cmd = `forge verify-contract --chain-id ${chainId} --num-of-optimizations ${numOfOptimizations} --watch --constructor-args ${constructorArgs} --compiler-version ${compiler} ${address} ${taskArgs.artifact} ${args}`;
    console.log(cmd);

    const result = await shell.exec(cmd, { fatal: true });

    if (result.code != 0) {
        process.exit(result.code);
    }
}