import {$} from "bun";
import type {TaskArgs, TaskFunction, TaskMeta} from "../../types";
import type {Tooling} from "../../tooling";
import {join} from "path";
import chalk from "chalk";
import {restoreFoundryProject} from "../utils/deployment";

// usage example:
// bun task verify --network base --deployment Base_Create3Factory
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
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    await $`bun run build`;

    const apiKey = tooling.network.config.api_key as string;
    const forgeVerifyExtraArgs = tooling.network.config.forgeVerifyExtraArgs || "";
    const chainId = tooling.getChainIdByName(tooling.network.name);
    let deployments = await tooling.getMatchingDeployments(taskArgs.deployment as string, chainId);

    if (deployments.length === 0) {
        console.error(`No deployments found for ${taskArgs.deployment}`);
        process.exit(1);
    }

    for (const deployment of deployments) {
        try {
            console.log(`Trying to verify using artifact...`);
            await verifyUsingArtifact(deployment, chainId, apiKey, forgeVerifyExtraArgs, tooling);
            console.log(`Verification successful!`);
        } catch (error) {
            console.log(`Verification using artifact failed. Error: ${error}`);
        }

        try {
            console.log(`Trying to verify using standardJsonInput...`);
            await verifyUsingStandardJsonInput(deployment, chainId, apiKey, forgeVerifyExtraArgs, tooling);
            console.log(`Verification successful!`);
        } catch (error) {
            console.log(`Verification using standardJsonInput failed. Error: ${error}`);
        }
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

    if (!artifact_full_path) {
        throw new Error("artifact_path not found in deployment file");
    }
    if (!compiler) {
        throw new Error("compiler setting not found in deployment file");
    }
    if (!standardJsonInput) {
        throw new Error("standardJsonInput not found in deployment file");
    }

    const tempDir = join(tooling.config.foundry.cache_path, "__verify_standard_json_input");

    const artifactFullPath = await restoreFoundryProject(tempDir, standardJsonInput, compiler, artifact_full_path);

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
        throw new Error("Verification failed");
    }
}

async function verifyUsingArtifact(deployment: any, chainId: number, apiKey: string, forgeVerifyExtraArgs: string, tooling: Tooling) {
    const {artifact_full_path} = deployment;
    if (!artifact_full_path) {
        throw new Error("artifact_full_path not found in deployment file, skipping verification");
    }

    const [artifactPath, contractName] = artifact_full_path.split(":");
    const artifact = await tooling.getArtifact(`${artifactPath}:${contractName}`);
    const numOfOptimizations = artifact.metadata.settings.optimizer.runs;
    const compiler = artifact.metadata.compiler.version;

    let args = "";
    if (apiKey) {
        args = `-e ${apiKey} ${forgeVerifyExtraArgs || ""}`;
    } else {
        args = forgeVerifyExtraArgs || "";
    }

    const baseCmd = `forge verify-contract --num-of-optimizations ${numOfOptimizations} --watch --constructor-args ${deployment.args_data} --compiler-version ${compiler} ${deployment.address} ${artifact_full_path} ${args}`;
    const cmd = `${baseCmd} --chain-id ${chainId} `;
    console.log(cmd);

    let result = await $`${cmd.split(" ")}`.nothrow();

    if (result.exitCode !== 0) {
        console.log("Trying without --chain-id...");
        result = await $`${baseCmd.split(" ")}`.nothrow();
        console.log(cmd);

        if (result.exitCode !== 0) {
            throw new Error("Verification failed");
        }
    }
}
