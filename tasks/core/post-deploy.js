const shell = require('shelljs');
const fs = require('fs');

module.exports = async function (taskArgs, hre) {
    const { getAllNetworks, getArtifact, getNetworkConfigByName, getAllDeploymentsByChainId } = hre;

    const networks = await getAllNetworks();
    for (const network of networks) {
        const config = getNetworkConfigByName(network);
        const deployments = await getAllDeploymentsByChainId(config.chainId);

        for (const deployment of deployments) {
            let artifactFullPath = deployment.artifact_full_path;
            if (!artifactFullPath) {
                continue;
            }

            const artifact = await getArtifact(artifactFullPath);
            const numOfOptimizations = artifact.metadata.settings.optimizer.runs;
            const compiler = artifact.metadata.compiler.version;
            const constructorArgs = deployment.args_data;

            const [firstKey, firstValue] = Object.entries(artifact.metadata.settings.compilationTarget)[0];
            artifactFullPath = `${firstKey}:${firstValue}`;

            const cmd = `forge verify-contract 0x0000000000000000000000000000000000000000 --chain-id ${config.chainId} --num-of-optimizations ${numOfOptimizations} --constructor-args ${constructorArgs} --compiler-version ${compiler} ${artifactFullPath} --show-standard-json-input`;

            const result = await shell.exec(cmd, { silent: true, fatal: true });

            if (result.code != 0) {
                process.exit(result.code);
            }

            deployment.standardJsonInput = JSON.parse(result);
            const path = deployment.__extra.path;
            delete deployment.__extra;
            fs.writeFileSync(path, JSON.stringify(deployment, null, 2));
        }
    }
}