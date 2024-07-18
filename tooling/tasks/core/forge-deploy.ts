import { $ } from 'bun';
import type { TaskArgs, TaskFunction, TaskMeta, Tooling } from '../../types';
import path from 'path';
import fs from 'fs';
import { rm } from 'fs/promises';
import { confirm } from '@inquirer/prompts';

export const meta: TaskMeta = {
    name: 'core:forge-deploy',
    description: 'Deploy scripts using forge',
    options: {
        broadcast: {
            type: 'boolean',
            description: 'Broadcast the deployment',
        },
        verify: {
            type: 'boolean',
            description: 'Verify the deployment',
        },
        noConfirm: {
            type: 'boolean',
            description: 'Skip confirmation',
        },
        script: {
            type: 'string',
            required: true,
            description: 'Script to deploy',
        },
        extra: {
            type: 'string',
            description: 'Extra arguments to pass to forge',
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
    let env_args = "";

    if (!fs.existsSync(script)) {
        console.error(`Script ${taskArgs.script} does not exist`);
        process.exit(1);
    }

    if (taskArgs.broadcast) {
        broadcast_args = "--broadcast";

        if (!taskArgs.noConfirm) {
            const answers = await confirm({
                default: false,
                message: `This is going to: \n\n- Deploy contracts to ${tooling.network.name} ${taskArgs.verify ? "\n- Verify contracts" : "\n- Leave the contracts unverified"} \n\nAre you sure?`,
            });

            if (!answers) {
                process.exit(0);
            }
        }

        await rm(path.join(tooling.projectRoot, foundry.broadcast), { recursive: true, force: true });
    }

    if (taskArgs.verify) {
        if (apiKey) {
            verify_args = `--verify --etherscan-api-key ${apiKey}`;
        } else {
            const answers = await confirm({
                default: false,
                message: `You are trying to verify contracts on ${tooling.network.name} without an etherscan api key. \n\nAre you sure?`
            });

            if (!answers) {
                process.exit(0);
            }

            verify_args = `--verify`;
        }
    }

    let FOUNDRY_PROFILE = '';

    // rebuild because it's not using the default, so forge verify-contract will not get the right evmVersion from the artifact
    if (tooling.network.config.profile) {
        FOUNDRY_PROFILE = `FOUNDRY_PROFILE=${tooling.network.config.profile} `;
    }

    const cmd = `${FOUNDRY_PROFILE}${env_args ? env_args + ' ' : ''}forge script ${script} --rpc-url ${tooling.network.config.url} ${broadcast_args} ${verify_args} ${taskArgs.extra || ""} ${tooling.network.config.forgeDeployExtraArgs || ""} --slow --private-key *******`.replace(/\s+/g, ' ');
    console.log(cmd);
    const result = await $`${cmd.replace('*******', process.env.PRIVATE_KEY as string)}`.nothrow();

    await $`./forge-deploy sync`.nothrow().quiet();
    await $`bun task post-deploy`;

    if (result.exitCode !== 0) {
        process.exit(result.exitCode);
    }
}
