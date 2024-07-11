const shell = require('shelljs');
const fs = require('fs');
const path = require('path');
const { config } = require('dotenv-defaults');

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

            let FOUNDRY_PROFILE = '';

            // rebuild because it's not using the default, so forge verify-contract will not get the right evmVersion from the artifact
            if (config.profile) {
                FOUNDRY_PROFILE = `FOUNDRY_PROFILE=${config.profile} `;
            }

            const artifact = await getArtifact(artifactFullPath)
            const numOfOptimizations = artifact.metadata.settings.optimizer.runs;
            const compiler = artifact.metadata.compiler.version;
            const constructorArgs = deployment.args_data;

            const [firstKey, firstValue] = Object.entries(artifact.metadata.settings.compilationTarget)[0];
            artifactFullPath = `${firstKey}:${firstValue}`;
            const baseCmd = `${FOUNDRY_PROFILE}forge verify-contract ${deployment.address} --chain-id ${config.chainId} --num-of-optimizations ${numOfOptimizations} --constructor-args ${constructorArgs} --compiler-version ${compiler} ${artifactFullPath}`;
            console.log(baseCmd);
            console.log();
            console.log(`[${network}] Adding ${deployment.__extra.name} metadata... `);
            let result = await shell.exec(`${baseCmd} --show-standard-json-input`, { silent: true, fatal: true });

            if (result.code != 0) {
                process.exit(result.code);
            }

            deployment.standardJsonInput = JSON.parse(result);
            const filepath = deployment.__extra.path;

            // write json metadata cache for quicker access during contract verification
            const cacheFolder = path.join(hre.config.foundry.cache_path, 'standardJsonInput');
            const standardJsonInputCache = path.join(cacheFolder, `${path.basename(filepath, '.json')}.metadata.json`);

            // create cacheFolder folder
            if (!fs.existsSync(cacheFolder)) {
                fs.mkdirSync(cacheFolder, { recursive: true });
            }

            fs.writeFileSync(standardJsonInputCache, JSON.stringify(deployment.standardJsonInput, null, 2), { encoding: 'utf8', flag: 'w' });

            let sourcifyFailed = false;
            if (!config.disableSourcify) {
                if ((await shell.exec(`${baseCmd} --verifier sourcify`, { silent: false, fatal: false })).code != 0) {
                    sourcifyFailed = true;
                }
            } else {
                console.log(`Sourcify verification disabled for ${deployment.__extra.name}. Skipped.`);
            }

            if (!sourcifyFailed) {
                console.log(`Writing metadata cache ${standardJsonInputCache}... `);
                delete deployment.__extra;
                deployment.compiler = compiler;
                fs.writeFileSync(filepath, JSON.stringify(deployment, null, 2), { encoding: 'utf8', flag: 'w' });
            }
        }
    }
}