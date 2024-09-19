import { $ } from 'bun';
import type { NetworkName, TaskArgs, TaskFunction, TaskMeta } from '../../types';
import { ForgeDeployOptions } from './forge-deploy';
import type { Tooling } from '../../tooling';

export const meta: TaskMeta = {
    name: 'core/forge-deploy-multichain',
    description: 'Deploy scripts using forge to multiple networks',
    options: {
        ...ForgeDeployOptions
    },
    positionals: {
        name: 'networks',
        description: 'Networks to deploy to',
        required: true
    }
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    let networks = taskArgs.networks as NetworkName[];

    if (networks.length == 1 && (networks as string[])[0] == "all") {
        networks = tooling.getAllNetworks();
    }

    for (const network of networks) {
        tooling.changeNetwork(network);
        console.log(`Deploying to ${network}...`);
        await $`bun task forge-deploy --network ${network} --script ${taskArgs.script} ${taskArgs.broadcast ? '--broadcast' : ''} ${taskArgs.verify ? '--verify' : ''} ${taskArgs.noConfirm ? '--no-confirm' : ''}`;
    }
}