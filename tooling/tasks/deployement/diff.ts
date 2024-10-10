import {$} from "bun";
import type {DeploymentArtifact, TaskArgs, TaskFunction, TaskMeta} from "../../types";
import {getSolFiles, type Tooling} from "../../tooling";
import {join} from "path";
import chalk from "chalk";
import {restoreFoundryProject} from "../utils/deployement";

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
    const deployment = await tooling.getDeploymentWithSuggestions(taskArgs.deployment as string, chainId);

    const {standardJsonInput, compiler, artifact_full_path} = deployment as DeploymentArtifact;

    if (!compiler) {
        console.error("Compiler not found for deployment");
        process.exit(1);
    }
    if (!standardJsonInput) {
        console.error("Standard JSON input not found for deployment");
        process.exit(1);
    }
    if (!artifact_full_path) {
        console.error("Artifact full path not found for deployment");
        process.exit(1);
    }

    const tempDir = join(tooling.config.foundry.cache_path, "__diff_standard_json_input");

    // Recreate the project from standard JSON input
    await restoreFoundryProject(tempDir, standardJsonInput, compiler, artifact_full_path, false);

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
            const result = await $`${diffCmd.split(" ")}`.nothrow();

            if (result.exitCode !== 0) {
                hasDifferences = true;
                console.log(chalk.cyan(`\n=== Differences in ${file} ===`));
                const lines = result.stdout.toString().split("\n");
                const filteredLines = lines.filter((line: string) => line.startsWith("+") || line.startsWith("-") || line.startsWith("@"));
                console.log(filteredLines.join("\n"));
            }
        }
    }

    if (!hasDifferences) {
        console.log(chalk.green("\nAll files are identical. ✅"));
    }
};
