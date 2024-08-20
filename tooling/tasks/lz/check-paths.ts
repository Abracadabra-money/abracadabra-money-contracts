import { ethers } from 'ethers';
import type { TaskFunction, TaskMeta, TaskArgs } from '../../types';
import type { Tooling } from '../../tooling';

export const meta: TaskMeta = {
    name: 'lz/check-paths',
    description: 'Check LayerZero paths between networks',
    options: {
        token: {
            type: "string",
            description: "oft type",
            choices: ["mim", "spell"],
            required: true
        }
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    taskArgs.networks = Object.keys(tooling.config.networks);

    for (const fromNetwork of taskArgs.networks) {
        const config = tooling.getNetworkConfigByName(fromNetwork);
        if (config.extra?.mimLzUnsupported) continue;

        await tooling.changeNetwork(fromNetwork);
        let endpoint = tooling.getAddressByLabel(fromNetwork, "LZendpoint");

        if (!endpoint) {
            console.log(`No LZendpoint address found for ${fromNetwork}`);
            process.exit(1);
        }

        const endpointContract = await tooling.getContractAt("ILzEndpoint", endpoint);

        for (const toNetwork of taskArgs.networks) {
            if (fromNetwork === toNetwork) {
                continue;
            }

            const config = tooling.getNetworkConfigByName(toNetwork);

            if (config.extra?.mimLzUnsupported) continue;

            console.log(`Checking ${fromNetwork} -> ${toNetwork}`);
            const sendLibraryAddress = await endpointContract.defaultSendLibrary();
            const sendLibrary = await tooling.getContractAt("ILzUltraLightNodeV2", sendLibraryAddress);

            const networkConfig = tooling.getNetworkConfigByName(toNetwork);
            const appConfig = await sendLibrary.defaultAppConfig(networkConfig.lzChainId);

            if (appConfig.relayer === ethers.constants.AddressZero) {
                console.log(`No path for ${fromNetwork} -> ${toNetwork}`);
            }
        }
    }
};