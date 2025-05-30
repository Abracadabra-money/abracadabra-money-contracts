import {$} from "bun";
import type {NetworkName, TaskArgs, TaskFunction, TaskMeta} from "../../types";
import {ForgeDeployOptions} from "./forge-deploy";
import type {Tooling} from "../../tooling";
import {runTask} from "../../task-runner";

export const meta: TaskMeta = {
    name: "core/forge-deploy-multichain",
    description: "Deploy scripts using forge to multiple networks",
    options: {
        ...ForgeDeployOptions,
    },
    positionals: {
        name: "networks",
        description: "Networks to deploy to",
        required: true,
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    let networks = taskArgs.networks as NetworkName[];

    if (networks.length == 1 && (networks as string[])[0] == "all") {
        networks = tooling.getAllNetworks();
    }

    for (const network of networks) {
        await tooling.changeNetwork(network);
        console.log(`Deploying to ${network}...`);
        await runTask("forge-deploy", {
            network,
            script: taskArgs.script,
            broadcast: taskArgs.broadcast,
            verify: taskArgs.verify,
            noConfirm: taskArgs.noConfirm,
        });
    }
};
