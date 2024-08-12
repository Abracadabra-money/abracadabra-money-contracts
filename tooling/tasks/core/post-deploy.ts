import type { DeploymentArtifact, TaskArgs, TaskFunction, TaskMeta, Tooling} from "../../types";
import path from "path";
import fs from "fs";
import {$} from "bun";

export const meta: TaskMeta = {
    name: "core:post-deploy",
    description: "Post deploy tasks",
};

export const task: TaskFunction = async (_: TaskArgs, tooling: Tooling) => {
    $`bun run build`;
    const networks = await tooling.getAllNetworks();
    for (const network of networks) {
        const config = tooling.getNetworkConfigByName(network);
        const deployments = await tooling.getAllDeploymentsByChainId(config.chainId);

        for (const deployment of deployments) {
            let artifactFullPath = deployment.artifact_full_path;
            if (!artifactFullPath || deployment.artifact_full_path?.trim() == "" || deployment.standardJsonInput) {
                continue;
            }

            let FOUNDRY_PROFILE = "";

            // rebuild because it's not using the default, so forge verify-contract will not get the right evmVersion from the artifact
            if (config.profile) {
                FOUNDRY_PROFILE = `FOUNDRY_PROFILE=${config.profile} `;
            }

            const artifact = await tooling.getArtifact(artifactFullPath);
            const numOfOptimizations = artifact.metadata.settings.optimizer.runs;
            const compiler = artifact.metadata.compiler.version;
            const constructorArgs = deployment.args_data;

            const [firstKey, firstValue] = Object.entries(artifact.metadata.settings.compilationTarget)[0];
            artifactFullPath = `${firstKey}:${firstValue}`;
            const baseCmd = `${FOUNDRY_PROFILE}forge verify-contract ${deployment.address} --chain-id ${config.chainId} --num-of-optimizations ${numOfOptimizations} --constructor-args ${constructorArgs} --compiler-version ${compiler} ${artifactFullPath}`;
            console.log(`[${network}] Adding ${deployment.name} metadata... `);

            const cmd = `${baseCmd} --show-standard-json-input`;
            let result = await $`${cmd.split(" ")}`.nothrow().quiet();

            if (result.exitCode != 0) {
                process.exit(result.exitCode);
            }

            deployment.standardJsonInput = result.json();
            const filepath = deployment.path as string;

            // write json metadata cache for quicker access during contract verification
            const cacheFolder = path.join(tooling.config.foundry.cache_path, "standardJsonInput");
            const standardJsonInputCache = path.join(cacheFolder, `${path.basename(filepath, ".json")}.metadata.json`);

            // create cacheFolder folder
            if (!fs.existsSync(cacheFolder)) {
                fs.mkdirSync(cacheFolder, {recursive: true});
            }

            fs.writeFileSync(standardJsonInputCache, JSON.stringify(deployment.standardJsonInput, null, 2), {encoding: "utf8", flag: "w"});

            let sourcifyFailed = false;
            if (!config.disableSourcify) {
                const cmd = `${baseCmd} --verifier sourcify`;

                if ((await $`${cmd.split(" ")}`.nothrow()).exitCode != 0) {
                    sourcifyFailed = true;
                }
            } else {
                console.log(`Sourcify verification disabled for ${deployment.name}. Skipped.`);
            }

            if (!sourcifyFailed) {
                console.log(`Writing metadata cache ${standardJsonInputCache}... `);

                const deploymentArtifact = {
                    ...deployment,
                    compiler,
                } as DeploymentArtifact;

                delete deploymentArtifact.name;
                delete deploymentArtifact.path;

                fs.writeFileSync(filepath, JSON.stringify(deploymentArtifact, null, 2), {encoding: "utf8", flag: "w"});
            }
        }
    }
};
