import {ethers} from "ethers";
import {type TaskFunction, type TaskMeta, type TaskArgs, NetworkName, type TaskArgValue} from "../../types";
import type {Tooling} from "../../tooling";
import {lz} from "../utils/lz";

export const meta: TaskMeta = {
    name: "lz/check-paths",
    description: "Check LayerZero paths between networks",
    options: {
        token: {
            type: "string",
            description: "Token to deploy",
            required: true,
            choices: ["mim", "spell", "bspell"],
            transform: (value: TaskArgValue) => (value as string).toUpperCase(),
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const tokenName = taskArgs.token as string;
    const supportedNetworks = lz.getSupportedNetworks(tokenName);

    for (const fromNetwork of supportedNetworks) {
        await tooling.changeNetwork(fromNetwork);
        let endpoint = tooling.getAddressByLabel(fromNetwork, "LZendpoint");

        if (!endpoint) {
            console.log(`No LZendpoint address found for ${fromNetwork}`);
            process.exit(1);
        }

        const endpointContract = await tooling.getContractAt("ILzEndpoint", endpoint);

        for (const toNetwork of supportedNetworks) {
            if (fromNetwork === toNetwork) {
                continue;
            }

            console.log(`Checking ${fromNetwork} -> ${toNetwork}`);
            const sendLibraryAddress = await endpointContract.defaultSendLibrary();
            const sendLibrary = await tooling.getContractAt("ILzUltraLightNodeV2", sendLibraryAddress);

            const networkConfig = tooling.getNetworkConfigByName(toNetwork);
            const appConfig = await sendLibrary.defaultAppConfig(networkConfig.lzChainId);

            if (appConfig.relayer === ethers.ZeroAddress) {
                console.log(`No path for ${fromNetwork} -> ${toNetwork}`);
            }
        }
    }
};
