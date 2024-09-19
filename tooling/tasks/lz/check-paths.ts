import { ethers } from 'ethers';
import { type TaskFunction, type TaskMeta, type TaskArgs, NetworkName, type TaskArgValue } from '../../types';
import type { Tooling } from '../../tooling';

export const meta: TaskMeta = {
    name: 'lz/check-paths',
    description: 'Check LayerZero paths between networks',
    options: {
        token: {
            type: "string",
            description: "oft type",
            choices: ["mim", "spell"],
            required: true,
            transform: (value: TaskArgValue) => (value as string).toUpperCase(),
        }
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const networks = Object.values(NetworkName);

    for (const fromNetwork of networks) {
        const config = tooling.getNetworkConfigByName(fromNetwork);
        if (config.extra?.mimLzUnsupported) continue;

        await tooling.changeNetwork(fromNetwork);
        let endpoint = tooling.getAddressByLabel(fromNetwork, "LZendpoint");

        if (!endpoint) {
            console.log(`No LZendpoint address found for ${fromNetwork}`);
            process.exit(1);
        }

        const endpointContract = await tooling.getContractAt("ILzEndpoint", endpoint);

        for (const toNetwork of networks) {
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