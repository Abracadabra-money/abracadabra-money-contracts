import type {Tooling} from "../../tooling";
import type {NetworkName, TaskArgs, TaskFunction, TaskMeta} from "../../types";

export const meta: TaskMeta = {
    name: "lz/ua-get-default-config",
    description: "Get LayerZero configuration for specified networks",
    options: {
        networks: {
            type: "string",
            description: 'Comma-separated list of networks or "all"',
            required: true,
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    let networks = (taskArgs.networks as string).split(",") as NetworkName[];

    if (networks.length === 1 && (networks as string[])[0] === "all") {
        networks = tooling.getAllNetworksLzSupported();
    }

    const configByNetwork = [];
    for (let network of networks) {
        await tooling.changeNetwork(network);

        const endpointAddress = tooling.getAddressByLabel(network, "LZendpoint") as `0x${string}`;
        const endpoint = await tooling.getContractAt("ILzEndpoint", endpointAddress);

        console.log(`Getting config for ${network}...`);
        const sendVersion = await endpoint.defaultSendVersion();
        const receiveVersion = await endpoint.defaultReceiveVersion();
        const sendLibraryAddress = await endpoint.defaultSendLibrary();
        const messagingLibrary = await tooling.getContractAt("ILzUltraLightNodeV2", sendLibraryAddress);

        const config = await messagingLibrary.defaultAppConfig(tooling.getLzChainIdByName(network));

        configByNetwork.push({
            network,
            sendVersion,
            receiveVersion,
            inboundProofLibraryVersion: config.inboundProofLibraryVersion,
            inboundBlockConfirmations: config.inboundBlockConfirmations.toNumber(),
            relayer: config.relayer,
            outboundProofType: config.outboundProofType,
            outboundBlockConfirmations: config.outboundBlockConfirmations.toNumber(),
            oracle: config.oracle,
        });
    }

    console.table(configByNetwork);
};
