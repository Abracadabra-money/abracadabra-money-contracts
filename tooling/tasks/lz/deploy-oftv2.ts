import { $ } from 'bun';
import type { TaskArgs, TaskFunction, TaskMeta } from '../../types';
import { tokenDeploymentNamePerNetwork, spellTokenDeploymentNamePerNetwork } from '../utils/lz';
import type { Tooling } from '../../tooling';

export const meta: TaskMeta = {
    name: 'lz/deploy-oftv2',
    description: 'Deploy LayerZero contracts',
    options: {
        token: {
            type: 'string',
            description: 'Token to deploy',
            required: true,
            choices: ['mim', 'spell'],
        },
        broadcast: {
            type: 'boolean',
            description: 'Broadcast the deployment',
            required: false,
        },
        verify: {
            type: 'boolean',
            description: 'Verify the deployment',
            required: false,
        },
        noConfirm: {
            type: 'boolean',
            description: 'Skip confirmation',
            required: false,
        }
    },
    positionals: {
        name: 'networks',
        description: 'Networks to deploy and configure',
        required: true,
    }
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const token = taskArgs.token;
    const networks = taskArgs.networks as string[];

    let script: string = '';
    let deploymentNamePerNetwork: { [key: string]: string } = {};

    if (token === 'mim') {
        script = 'MIMLayerZero';
        deploymentNamePerNetwork = tokenDeploymentNamePerNetwork;
    } else if (token === 'spell') {
        script = 'SpellLayerZero';
        deploymentNamePerNetwork = spellTokenDeploymentNamePerNetwork;
    }

    await $`bun run build`;
    await $`bun task forge-deploy-multichain --script ${script} ${taskArgs.broadcast ? '--broadcast' : ''} ${taskArgs.verify ? '--verify' : ''} ${taskArgs.noConfirm ? '--no-confirm' : ''} ${networks}`;

    // Only run the following if we are broadcasting
    if (taskArgs.broadcast) {
        for (const srcNetwork of networks) {
            const minGas = 100_000;

            for (const targetNetwork of Object.keys(deploymentNamePerNetwork)) {
                if (targetNetwork === srcNetwork) continue;

                console.log(" -> ", targetNetwork);
                await $`bun task set-min-dst-gas --network ${srcNetwork} --targetNetwork ${targetNetwork} --contract ${deploymentNamePerNetwork[srcNetwork]} --packetType 0 --minGas ${minGas}`;
                console.log(`[${srcNetwork}] PacketType 0 - Setting minDstGas for ${deploymentNamePerNetwork[srcNetwork]} to ${minGas} for ${deploymentNamePerNetwork[targetNetwork]}`);

                await $`bun task set-min-dst-gas --network ${srcNetwork} --targetNetwork ${targetNetwork} --contract ${deploymentNamePerNetwork[srcNetwork]} --packetType 1 --minGas ${minGas}`;
                console.log(`[${srcNetwork}] PacketType 1 - Setting minDstGas for ${deploymentNamePerNetwork[srcNetwork]} to ${minGas} for ${deploymentNamePerNetwork[targetNetwork]}`);

                await $`bun task set-trusted-remote --network ${srcNetwork} --targetNetwork ${targetNetwork} --localContract ${deploymentNamePerNetwork[srcNetwork]} --remoteContract ${deploymentNamePerNetwork[targetNetwork]}`;
                console.log(`[${srcNetwork}] Setting trusted remote for ${deploymentNamePerNetwork[srcNetwork]} to ${deploymentNamePerNetwork[targetNetwork]}`);
            }
        }
    }
};
