import {$} from "bun";
import type {TaskArgs, TaskFunction, TaskMeta, Tooling} from "../../types";

// usage example:
// bun task verify --network base --deployment Base_Create3Factory --artifact src/mixins/Create3Factory.sol:Create3Factory
// use --show-standard-json-input to get the json input to manually verify on etherscan
export const meta: TaskMeta = {
    name: "core:verify",
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
            required: true,
        },
        showStandardJsonInput: {
            type: "boolean",
            description: "Show the standard JSON input",
            required: false,
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    await $`bun run build`;

    const apiKey = tooling.network.config.api_key;
    const forgeVerifyExtraArgs = tooling.network.config.forgeVerifyExtraArgs;
    const chainId = tooling.getChainIdByNetworkName(tooling.network.name);
    let deployment = await tooling.tryGetDeployment(taskArgs.deployment as string, chainId);

    // try to get deployment with chain name if not found
    if (!deployment) {
        const capitalizedNetwork = tooling.network.name.charAt(0).toUpperCase() + tooling.network.name.slice(1);
        deployment = await tooling.tryGetDeployment(`${capitalizedNetwork}_${taskArgs.deployment}`, chainId);

        if(!deployment) {
            console.error(`Deployment ${taskArgs.deployment} or ${capitalizedNetwork}_${taskArgs.deployment} not found`);
            process.exit(1);
        }
    }

    const address = deployment.address;
    const constructorArgs = deployment.args_data;
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

    const baseCmd = `forge verify-contract --num-of-optimizations ${numOfOptimizations} --watch --constructor-args ${constructorArgs} --compiler-version ${compiler} ${address} ${taskArgs.artifact} ${args}`;
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
};
