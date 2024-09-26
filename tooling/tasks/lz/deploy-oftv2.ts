import type {NetworkName, TaskArgs, TaskArgValue, TaskFunction, TaskMeta} from "../../types";
import type {Tooling} from "../../tooling";
import {exec} from "../utils";
import {lz} from "../utils/lz";

export const meta: TaskMeta = {
    name: "lz/deploy-oftv2",
    description: "Deploy LayerZero contracts",
    options: {
        token: {
            type: "string",
            description: "Token to deploy",
            required: true,
            choices: ["mim", "spell", "bspell"],
            transform: (value: TaskArgValue) => (value as string).toUpperCase(),
        },
        stage: {
            type: "string",
            description: "Stage to execute",
            required: true,
            choices: ["deploy", "configure"],
        },
    },
    positionals: {
        name: "networks",
        description: "Networks to deploy and configure",
        required: true,
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const tokenName = taskArgs.token as string;
    const networks = taskArgs.networks as NetworkName[];
    const supportedNetworks = lz.getSupportedNetworks(tokenName);

    if (taskArgs.stage === "deploy") {
        let script = "";

        if (tokenName === "MIM") {
            script = "MIMLayerZero";
        } else if (tokenName === "SPELL") {
            script = "SpellLayerZero";
        } else if (tokenName === "BSPELL") {
            script = "BoundSpellLayerZero";
        }

        await exec(`bun run clean`);
        await exec(`bun run build`);
        await exec(`bun task forge-deploy-multichain --script ${script} --broadcast --verify --no-confirm ${networks.join(" ")}`);
    }

    if (taskArgs.stage === "configure") {
        for (const srcNetwork of networks) {
            const minGas = 100_000;

            const sourceLzDeployementConfig = lz.getDeployementConfig(tooling, tokenName, srcNetwork);

            for (const targetNetwork of supportedNetworks) {
                if (targetNetwork === srcNetwork) continue;

                const targetLzDeployementConfig = lz.getDeployementConfig(tooling, tokenName, targetNetwork);

                console.log(" -> ", targetNetwork);
                await exec(
                    `bun task set-min-dst-gas --network ${srcNetwork} --target-network ${targetNetwork} --contract ${sourceLzDeployementConfig.oft} --packet-type 0 --min-gas ${minGas}`
                );
                console.log(
                    `[${srcNetwork}] PacketType 0 - Setting minDstGas for ${sourceLzDeployementConfig.oft} to ${minGas} for ${targetLzDeployementConfig.oft}`
                );

                await exec(
                    `bun task set-min-dst-gas --network ${srcNetwork} --target-network ${targetNetwork} --contract ${sourceLzDeployementConfig.oft} --packet-type 1 --min-gas ${minGas}`
                );
                console.log(
                    `[${srcNetwork}] PacketType 1 - Setting minDstGas for ${sourceLzDeployementConfig.oft} to ${minGas} for ${targetLzDeployementConfig.oft}`
                );

                await exec(
                    `bun task set-trusted-remote --network ${srcNetwork} --target-network ${targetNetwork} --local-contract ${sourceLzDeployementConfig.oft} --remote-contract ${targetLzDeployementConfig.oft}`
                );
                console.log(
                    `[${srcNetwork}] Setting trusted remote for ${sourceLzDeployementConfig.oft} to ${targetLzDeployementConfig.oft}`
                );
            }
        }
    }
};
