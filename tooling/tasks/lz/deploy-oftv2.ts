import type {TaskArgs, TaskFunction, TaskMeta} from "../../types";
import {mimTokenDeploymentNamePerNetwork, spellTokenDeploymentNamePerNetwork} from "../utils/lz";
import type {Tooling} from "../../tooling";
import {exec} from "../utils";

export const meta: TaskMeta = {
    name: "lz/deploy-oftv2",
    description: "Deploy LayerZero contracts",
    options: {
        token: {
            type: "string",
            description: "Token to deploy",
            required: true,
            choices: ["mim", "spell"],
        },
    },
    positionals: {
        name: "networks",
        description: "Networks to deploy and configure",
        required: true,
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const token = taskArgs.token;
    const networks = taskArgs.networks as string[];

    let script: string = "";
    let deploymentNamePerNetwork: {[key: string]: string} = {};

    if (token === "mim") {
        script = "MIMLayerZero";
        deploymentNamePerNetwork = mimTokenDeploymentNamePerNetwork;
    } else if (token === "spell") {
        script = "SpellLayerZero";
        deploymentNamePerNetwork = spellTokenDeploymentNamePerNetwork;
    }

    await exec(`bun run clean`);
    await exec(`bun run build`);
    await exec(`bun task forge-deploy-multichain --script ${script} --broadcast --verify --no-confirm ${networks.join(" ")}`);

    for (const srcNetwork of networks) {
        const minGas = 100_000;

        for (const targetNetwork of Object.keys(deploymentNamePerNetwork)) {
            if (targetNetwork === srcNetwork) continue;

            console.log(" -> ", targetNetwork);
            await exec(
                `bun task set-min-dst-gas --network ${srcNetwork} --target-network ${targetNetwork} --contract ${deploymentNamePerNetwork[srcNetwork]} --packet-type 0 --min-gas ${minGas}`
            );
            console.log(
                `[${srcNetwork}] PacketType 0 - Setting minDstGas for ${deploymentNamePerNetwork[srcNetwork]} to ${minGas} for ${deploymentNamePerNetwork[targetNetwork]}`
            );

            await exec(
                `bun task set-min-dst-gas --network ${srcNetwork} --target-network ${targetNetwork} --contract ${deploymentNamePerNetwork[srcNetwork]} --packet-type 1 --min-gas ${minGas}`
            );
            console.log(
                `[${srcNetwork}] PacketType 1 - Setting minDstGas for ${deploymentNamePerNetwork[srcNetwork]} to ${minGas} for ${deploymentNamePerNetwork[targetNetwork]}`
            );

            await exec(
                `bun task set-trusted-remote --network ${srcNetwork} --target-network ${targetNetwork} --local-contract ${deploymentNamePerNetwork[srcNetwork]} --remote-contract ${deploymentNamePerNetwork[targetNetwork]}`
            );
            console.log(
                `[${srcNetwork}] Setting trusted remote for ${deploymentNamePerNetwork[srcNetwork]} to ${deploymentNamePerNetwork[targetNetwork]}`
            );
        }
    }
};
