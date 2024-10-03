import {$, file} from "bun";
import fs from "fs";
import {mkdir, rm, mkdtemp} from "node:fs/promises";
import {join, dirname} from "path";
import type {TaskArgs, TaskFunction, TaskMeta} from "../../types";
import type {Tooling} from "../../tooling";
import os from "os";
import chalk from "chalk";

// usage example:
// bun task verify --network base --deployment Base_Create3Factory --artifact src/mixins/Create3Factory.sol:Create3Factory
// use --show-standard-json-input to get the json input to manually verify on etherscan
export const meta: TaskMeta = {
    name: "core/verify",
    description: "Verify contract or get standard json input",
    options: {
        network: {
            type: "string",
            description: "Network to use",
            required: true,
        },
        deployment: {
            type: "string",
            description: "Deployment name to verify (ex: Base_Create3Factory)",
            required: true,
        },
        artifact: {
            type: "string",
            description: "Artifact to use for verification (ex: src/mixins/Create3Factory.sol:Create3Factory)",
            required: false,
        },
        showStandardJsonInput: {
            type: "boolean",
            description: "Show the standard JSON input",
            required: false,
        },
        useStandardJsonInput: {
            type: "boolean",
            description: "Use standard JSON input from deployment file for verification",
            required: false,
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    await $`bun run build`;

    const apiKey = tooling.network.config.api_key as string;
    const forgeVerifyExtraArgs = tooling.network.config.forgeVerifyExtraArgs || "";
    const chainId = tooling.getChainIdByName(tooling.network.name);
    let deployment = await tooling.tryGetDeployment(taskArgs.deployment as string, chainId);

    // try to get deployment with chain name if not found
    if (!deployment) {
        const capitalizedNetwork = tooling.network.name.charAt(0).toUpperCase() + tooling.network.name.slice(1);
        deployment = await tooling.tryGetDeployment(`${capitalizedNetwork}_${taskArgs.deployment}`, chainId);

        if (!deployment) {
            console.error(`Deployment ${taskArgs.deployment} or ${capitalizedNetwork}_${taskArgs.deployment} not found`);
            process.exit(1);
        }
    }

    if (taskArgs.useStandardJsonInput) {
        await verifyUsingStandardJsonInput(deployment, chainId, apiKey, forgeVerifyExtraArgs, tooling);
    } else {
        if (!taskArgs.artifact) {
            console.error("Artifact is required when not using standard JSON input");
            process.exit(1);
        }
        await verifyUsingArtifact(taskArgs, deployment, chainId, apiKey, forgeVerifyExtraArgs, tooling);
    }
};

async function verifyUsingStandardJsonInput(
    deployment: any,
    chainId: number,
    apiKey: string,
    forgeVerifyExtraArgs: string,
    tooling: Tooling
) {
    const {address, standardJsonInput, compiler, artifact_full_path} = deployment;

    if(!compiler) {
        console.error("compiler setting not found in deployment file");
        process.exit(1);
    }
    if(!artifact_full_path) {
        console.error("artifact_path not found in deployment file");
        process.exit(1);
    }
    if (!standardJsonInput) {
        console.error("standardJsonInput not found in deployment file");
        process.exit(1);
    }

    const [artifactPath, contractName] = artifact_full_path.split(":");

    // Create temporary directory
    const tempDir = join(tooling.config.foundry.cache_path, "__verify_standard_json_input");
    await rm(tempDir, {recursive: true, force: true});
    await mkdir(tempDir, {recursive: true});
    console.log(`Using temporary directory: ${tempDir}`);

    let artifactFullPath;

    // Reconstruct source files
    for (const [filePath, source] of Object.entries(standardJsonInput.sources)) {
        const content = (source as {content: string}).content;
        const fullPath = join(tempDir, filePath);
        console.log(chalk.gray(` • Writing file: ${fullPath}`));
        await mkdir(dirname(fullPath), {recursive: true});
        await Bun.write(fullPath, content);

        // Match artifact_full_path with source file path
        const parts = filePath.split("/");
        if(parts[parts.length - 1] === artifactPath) {
            artifactFullPath = `${filePath}:${contractName}`;
            console.log(chalk.gray(` • Matching artifact_full_path: ${artifactFullPath}`));
        }
    }

    if (!artifactFullPath) {
        console.error("Could not find matching source file for artifact_full_path");
        process.exit(1);
    }

    // Create foundry.toml
    const foundryConfig = `
[profile.default]
src = '.'
out = 'out'
libs = ['lib']
remappings = ${JSON.stringify(standardJsonInput.settings.remappings)}
optimizer = ${standardJsonInput.settings.optimizer.enabled}
optimizer_runs = ${standardJsonInput.settings.optimizer.runs}
evm_version = '${standardJsonInput.settings.evmVersion}'
solc_version = '${compiler}'
        `.trim();

    await Bun.write(join(tempDir, "foundry.toml"), foundryConfig);

    // Compile the project
    console.log("Compiling the project...");
    await $`forge build --root ${tempDir}`.quiet();

    // Verify the contract
    const constructorArgs = deployment.args_data;

    let baseVerifyCmd = `forge verify-contract --root ${tempDir} --num-of-optimizations ${standardJsonInput.settings.optimizer.runs} --watch --constructor-args ${constructorArgs} --compiler-version ${compiler} ${address} ${artifactFullPath}`;

    if (apiKey) {
        baseVerifyCmd += ` -e ${apiKey}`;
    }

    baseVerifyCmd += ` ${forgeVerifyExtraArgs}`;

    let verifyCmd = `${baseVerifyCmd} --chain-id ${chainId}`;

    console.log("Verifying the contract...");
    console.log(chalk.yellow(verifyCmd));

    let result = await $`${verifyCmd.split(" ")}`.nothrow();

    if (result.exitCode !== 0) {
        console.log("Verification failed. Trying without --chain-id...");
        verifyCmd = baseVerifyCmd;
        console.log(chalk.yellow(verifyCmd));
        result = await $`${verifyCmd.split(" ")}`.nothrow();
    }

    if (result.exitCode !== 0) {
        console.error("Verification failed");
        process.exit(result.exitCode);
    }

    console.log("Verification successful");
}

async function verifyUsingArtifact(
    taskArgs: TaskArgs,
    deployment: any,
    chainId: number,
    apiKey: string,
    forgeVerifyExtraArgs: string,
    tooling: Tooling
) {
    const artifact = await tooling.getArtifact(taskArgs.artifact as string);
    const numOfOptimizations = artifact.metadata.settings.optimizer.runs;
    const compiler = artifact.metadata.compiler.version;

    let args = "";
    if (apiKey) {
        args = `-e ${apiKey} ${forgeVerifyExtraArgs || ""}`;
    } else {
        args = forgeVerifyExtraArgs || "";
    }

    if (taskArgs.showStandardJsonInput) {
        args = `${args} --show-standard-json-input`;
    }

    const baseCmd = `forge verify-contract --num-of-optimizations ${numOfOptimizations} --watch --constructor-args ${deployment.args_data} --compiler-version ${compiler} ${deployment.address} ${taskArgs.artifact} ${args}`;
    const cmd = `${baseCmd} --chain-id ${chainId} `;
    console.log(cmd);

    let result = await $`${cmd.split(" ")}`.nothrow();

    if (result.exitCode !== 0) {
        console.log("Trying without --chain-id...");
        result = await $`${baseCmd.split(" ")}`.nothrow();
        console.log(cmd);

        if (result.exitCode !== 0) {
            process.exit(result.exitCode);
        }
    }
}
