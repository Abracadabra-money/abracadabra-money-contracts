import {$} from "bun";
import type {TaskArgs, TaskFunction, TaskMeta, Tooling} from "../../types";
import path from "path";
import fs from "fs";
import {rm} from "fs/promises";
import {confirm} from "@inquirer/prompts";
import chalk from "chalk";
import {exec} from "../utils";
import {CONSUMING_SCHEDULE_STORAGE_SLOT} from "../../../lib/openzeppelin-contracts/test/helpers/access-manager";

export const ForgeDeployOptions = {
    broadcast: {
        type: "boolean",
        description: "Broadcast the deployment",
    },
    verify: {
        type: "boolean",
        description: "Verify the deployment",
    },
    noConfirm: {
        type: "boolean",
        description: "Skip confirmation",
    },
    script: {
        type: "string",
        required: true,
        description: "Script to deploy",
    },
} as const;

export const meta: TaskMeta = {
    name: "core/forge-deploy",
    description: "Deploy scripts using forge",
    options: {
        ...ForgeDeployOptions,
        extra: {
            type: "string",
            description: "Extra arguments to pass to forge",
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    await $`bun task check-console-log`;

    console.log(`Using network ${tooling.network.name}`);

    const foundry = tooling.config.foundry;
    const apiKey = tooling.network.config.api_key;
    const script = path.join(tooling.projectRoot, foundry.script, `${taskArgs.script as string}.s.sol`);

    let broadcast_args = "";
    let verify_args = "";

    if (!fs.existsSync(script)) {
        console.error(`Script ${taskArgs.script} does not exist`);
        process.exit(1);
    }

    if (taskArgs.broadcast) {
        broadcast_args = "--broadcast";

        if (!taskArgs.noConfirm) {
            const answers = await confirm({
                default: false,
                message: `This is going to: \n\n- Deploy contracts to ${tooling.network.name} ${
                    taskArgs.verify ? "\n- Verify contracts" : "\n- Leave the contracts unverified"
                } \n\nAre you sure?`,
            });

            if (!answers) {
                process.exit(0);
            }
        }

        await rm(path.join(tooling.projectRoot, foundry.broadcast), {recursive: true, force: true});
    }

    if (taskArgs.verify) {
        if (tooling.network.config.disableVerifyOnDeploy) {
            console.log(chalk.yellow(`Verify on deploy is disabled for ${tooling.network.name}. Use deploy:no-verify instead`));
            process.exit(0);
        }

        if (apiKey) {
            verify_args = `--verify --etherscan-api-key ${apiKey}`;
        } else if (apiKey !== null) {
            const answers = await confirm({
                default: false,
                message: `You are trying to verify contracts on ${tooling.network.name} without an etherscan api key. \n\nAre you sure?`,
            });

            if (!answers) {
                process.exit(0);
            }

            verify_args = `--verify`;
        }
    }

    if (tooling.network.config.profile) {
        console.log(chalk.blue(`Using profile ${tooling.network.config.profile}`));
    }

    let cmd = `forge script ${script} --rpc-url ${tooling.network.config.url} ${broadcast_args} ${verify_args} ${taskArgs.extra || ""} ${
        tooling.network.config.forgeDeployExtraArgs || ""
    } --slow`.replace(/\s+/g, " ");
    console.log(chalk.yellow(`${cmd} --private-key *******`));
    cmd = `${cmd} --private-key ${process.env.PRIVATE_KEY as string}`;

    const exitCode = await exec(cmd, {FOUNDRY_PROFILE: tooling.network.config.profile || ""}, {noThrow: true});

    if (exitCode !== 0) {
        console.error(
            `Failed to deploy ${taskArgs.script}. The contract might have been deployed. Check the logs above for more information.`
        );
        const runPostDeploy = await confirm({message: "Try to create the deployment files anyway?"});

        if (!runPostDeploy) {
            process.exit(1);
        } else {
            console.log("Forcing post-deploy task...");
            console.log(`If the contract was deployed but the script failed to verify,\n
                    run ${chalk.yellow(
                        `bun task verify --network ${tooling.network.name} --deployment <DeploymentName> --artifact src/path/to/contract.sol:contract`
                    )}\n
                    to verify the contracts. or, use json-standard-input from cache/standardJsonInput/<DeploymentName>.json to verify the contracts manually on the explorer.\n
                    Note: you might need to locate the "args_data" field (removing the 0x prefix from it) from the deployment for the constructor argument.`);
        }
    }

    await $`bun task sync-deployments`;
    await $`bun task post-deploy`;
};
