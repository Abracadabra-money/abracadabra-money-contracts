import {$} from "bun";
import type {DeploymentArtifact, TaskArgs, TaskFunction, TaskMeta} from "../../types";
import {getSolFiles, type Tooling} from "../../tooling";
import {join} from "path";
import chalk from "chalk";
import {restoreFoundryProject} from "../utils/deployment";
import select from "@inquirer/select";

export const meta: TaskMeta = {
    name: "deployment/diff",
    description: "Show diff between current project and recreated project from standard JSON input",
    options: {
        network: {
            type: "string",
            description: "Network to use",
            required: true,
        },
        deployment: {
            type: "string",
            description: "Deployment name to diff (ex: Base_Create3Factory)",
            required: true,
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const chainId = tooling.getChainIdByName(tooling.network.name);
    let {deployment, suggestions} = await tooling.getDeploymentWithSuggestionsAndSimilars(taskArgs.deployment as string, chainId);
    let {standardJsonInput, compiler, artifact_full_path} = deployment as DeploymentArtifact;

    if (!compiler || !standardJsonInput || !artifact_full_path) {
        deployment = undefined;
        console.error("Missing metadata for deployment.");

        if (suggestions.length === 1) {
            const confirmed = await confirm(`Did you want to try with the deployment "${suggestions[0]}"?`);

            if (confirmed) {
                console.log(`Selected deployment: ${suggestions[0]}`);
                taskArgs.deployment = suggestions[0];
                deployment = await tooling.getDeployment(suggestions[0], chainId);
            }
        } else if (suggestions.length > 1) {
            const selectedDeployment = await select({
                message: "Did you want to try with one of these deployments?",
                choices: suggestions.map((suggestion) => ({
                    name: suggestion,
                    value: suggestion,
                })),
            });

            if (selectedDeployment) {
                console.log(`Selected deployment: ${selectedDeployment}`);
                taskArgs.deployment = selectedDeployment;
                deployment = await tooling.getDeployment(selectedDeployment, chainId);
            }
        }
    }

    if (deployment) {
        ({standardJsonInput, compiler, artifact_full_path} = deployment as DeploymentArtifact);
    } else {
        process.exit(1);
    }

    const tempDir = join(tooling.config.foundry.cache_path, "__diff_standard_json_input");

    // Recreate the project from standard JSON input
    await restoreFoundryProject(tempDir, standardJsonInput, compiler, artifact_full_path as string, false);

    // Get the current project's src directory
    const currentSrcDir = tooling.config.foundry.src;

    // Get all .sol files from both directories
    const currentFiles = await getSolFiles(currentSrcDir);

    // Add files from foundry libs
    for (const libPath of tooling.config.foundry.libs) {
        const absoluteLibPath = libPath;
        const libFiles = await getSolFiles(absoluteLibPath);
        currentFiles.push(...libFiles);
    }

    let hasDifferences = false;

    // Compare each file
    for (const file of currentFiles) {
        const recreatedFile = join(tempDir, file);

        if (await Bun.file(recreatedFile).exists()) {
            const diffCmd = `diff --color=always -u ${recreatedFile} ${file}`;
            const result = await $`${diffCmd.split(" ")}`.quiet().nothrow();

            if (result.exitCode !== 0) {
                hasDifferences = true;
                console.log(chalk.cyan(`\n=== Differences in ${file} ===`));
                console.log(result.stdout.toString());
            }
        }
    }

    if (!hasDifferences) {
        console.log(chalk.green(`All files are identical to the deployment at ${chalk.yellow(deployment.address)} ✅`));
    } else {
        console.log(chalk.yellow(`Differences found between local files and deployment at ${chalk.cyan(deployment.address)}`));
    }
};
