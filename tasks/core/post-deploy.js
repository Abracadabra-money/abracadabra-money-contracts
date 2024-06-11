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
            if (!artifactFullPath || deployment.standardJsonInput) {
                continue;
            }

            const artifact = await getArtifact(artifactFullPath);
            const numOfOptimizations = artifact.metadata.settings.optimizer.runs;
            const compiler = artifact.metadata.compiler.version;
            const constructorArgs = deployment.args_data;

            const [firstKey, firstValue] = Object.entries(artifact.metadata.settings.compilationTarget)[0];
            artifactFullPath = `${firstKey}:${firstValue}`;
            const baseCmd = `forge verify-contract ${deployment.address} --chain-id ${config.chainId} --num-of-optimizations ${numOfOptimizations} --constructor-args ${constructorArgs} --compiler-version ${compiler} ${artifactFullPath}`;

            console.log(`[${network}] Adding ${deployment.__extra.name} metadata... `);
            let result = await shell.exec(`${baseCmd} --show-standard-json-input`, { silent: true, fatal: true });

            if (result.code != 0) {
                process.exit(result.code);
            }

            deployment.standardJsonInput = JSON.parse(result);

            if (!config.disableSourcify) {
                await shell.exec(`${baseCmd} --verifier sourcify`, { silent: false, fatal: true });
            } else {
                console.log(`Sourcify verification disabled for ${deployment.__extra.name}. Skipped.`);
            }


            const path = deployment.__extra.path;
            delete deployment.__extra;
            fs.writeFileSync(path, JSON.stringify(deployment, null, 2));
        }
    }
}