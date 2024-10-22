import {lz} from "../utils/lz";
import type {NetworkName, TaskArgs, TaskArgValue, TaskFunction, TaskMeta} from "../../types";
import type {Contract} from "ethers";
import type {Tooling} from "../../tooling";

export const meta: TaskMeta = {
    name: "lz/ua-get-config",
    description: "Check LayerZero configuration for a specific token",
    options: {
        token: {
            type: "string",
            description: "Token to check configuration for",
            required: true,
            choices: ["mim", "spell"],
            transform: (value: TaskArgValue) => (value as string).toUpperCase(),
        },
        from: {
            type: "string",
            description: "Source network",
            required: true,
        },
        to: {
            type: "string",
            description: 'Target networks (comma separated or "all")',
            required: true,
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const tokenName = taskArgs.token as string;

    const lzDeployementConfig = await lz.getDeployementConfig(tooling, tokenName, taskArgs.from as NetworkName);

    const network = taskArgs.from as NetworkName;
    tooling.changeNetwork(network);

    let toNetworks = (taskArgs.to as string).split(",") as NetworkName[];

    if (toNetworks.length === 1 && (toNetworks as string[])[0] === "all") {
        toNetworks = lz.getSupportedNetworks(tokenName);
    }

    const localChainId = tooling.getChainIdByName(network);
    const oft = await tooling.getContract(lzDeployementConfig.oft, localChainId);

    if (!oft) {
        console.error(`Deployment information isn't found for ${network}`);
        return;
    }

    const oftAddress = await oft.getAddress() as `0x${string}`;
    const endpointAddress = tooling.getAddressByLabel(network, "LZendpoint") as `0x${string}`;
    const endpoint = await tooling.getContractAt("ILzEndpoint", endpointAddress);

    const appConfig = await endpoint.uaConfigLookup(oftAddress);
    const sendVersion = appConfig.sendVersion;
    const receiveVersion = appConfig.receiveVersion;
    const sendLibraryAddress = sendVersion === 0n ? await endpoint.defaultSendLibrary() : appConfig.sendLibrary;
    const sendLibrary = await tooling.getContractAt("ILzUltraLightNodeV2", sendLibraryAddress);

    let receiveLibrary;
    if (sendVersion !== receiveVersion) {
        const receiveLibraryAddress =
            receiveVersion === 0n ? await endpoint.defaultReceiveLibraryAddress() : appConfig.receiveLibraryAddress;
        receiveLibrary = await tooling.getContractAt("ILzUltraLightNodeV2", receiveLibraryAddress);
    }

    const remoteConfigs = [];
    for (let toNetwork of toNetworks) {
        if (network === toNetwork) {
            continue;
        }

        const config = await lz.getApplicationConfig(
            tooling,
            toNetwork,
            sendLibrary as unknown as Contract,
            receiveLibrary as unknown as Contract,
            oftAddress
        );
        remoteConfigs.push(config);
    }

    console.log("Network            ", network);
    console.log("Application address", oftAddress);
    console.log("Send version       ", sendVersion);
    console.log("Receive version    ", receiveVersion);
    console.table(remoteConfigs);
};
