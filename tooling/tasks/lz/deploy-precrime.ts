import {utils} from "ethers";
import type {NetworkName, TaskArgs, TaskArgValue, TaskFunction, TaskMeta} from "../../types";
import type {Tooling} from "../../tooling";
import {exec} from "../utils";
import {lz} from "../utils/lz";

export const meta: TaskMeta = {
    name: "lz/deploy-precrime",
    description: "Deploy LayerZero Precrime contracts",
    options: {
        token: {
            type: "string",
            description: "Token to deploy (mim or spell)",
            required: true,
            choices: ["mim", "spell"],
            transform: (value: TaskArgValue) => (value as string).toUpperCase(),
        },
    },
    positionals: {
        name: "networks",
        description: "Networks to deploy and configure",
        required: true,
    },
};

export const BASE_SCRIPT_NAME = "PreCrime";

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const networks = taskArgs.networks as NetworkName[];
    const tokenName = taskArgs.token as string;
    const supportedNetworks = lz.getSupportedNetworks(tokenName);
    
    let script = "";
    if (tokenName === "MIM") {
        script = "PreCrime";
    } else if (tokenName === "SPELL") {
        script = "SpellPreCrime";
    }

    await exec(`bun run clean`);
    await exec(`bun run build`);
    await exec(`bun task forge-deploy-multichain --script ${script} --broadcast --verify --no-confirm ${networks.join(" ")}`);

    const deployerAddress = await (await tooling.getDeployer()).getAddress();

    for (const srcNetwork of networks) {
        tooling.changeNetwork(srcNetwork);

        const sourceLzDeployementConfig = await lz.getDeployementConfig(tooling, tokenName, srcNetwork);

        // get local contract
        const localContractInstance = await tooling.getContract(sourceLzDeployementConfig.precrime, tooling.network.config.chainId);
        let remoteChainIDs = [];
        let remotePrecrimeAddresses = [];

        for (const targetNetwork of supportedNetworks) {
            if (targetNetwork === srcNetwork) continue;

            const targetLzDeployementConfig = await lz.getDeployementConfig(tooling, tokenName, srcNetwork);

            console.log(`[${srcNetwork}] Adding Precrime for ${targetLzDeployementConfig.precrime}`);
            const remoteChainId = tooling.getNetworkConfigByName(targetNetwork).chainId;
            const remoteContractInstance = await tooling.getContract(targetLzDeployementConfig.precrime, remoteChainId);

            const bytes32address = utils.defaultAbiCoder.encode(["address"], [remoteContractInstance.address]);
            remoteChainIDs.push(tooling.getLzChainIdByName(targetNetwork));
            remotePrecrimeAddresses.push(bytes32address);
        }

        try {
            const tx = await (await localContractInstance.setRemotePrecrimeAddresses(remoteChainIDs, remotePrecrimeAddresses)).wait();
            console.log(`✅ [${tooling.network.name}] setRemotePrecrimeAddresses`);
            console.log(` tx: ${tx.transactionHash}`);
        } catch (e) {
            console.log(`❌ [${tooling.network.name}] setRemotePrecrimeAddresses`);
        }

        const token = await tooling.getContract(sourceLzDeployementConfig.oft, tooling.network.config.chainId);
        console.log(`Setting precrime address to ${localContractInstance.address}...`);

        if ((await token.precrime()) !== localContractInstance.address) {
            const owner = await token.owner();
            if (owner === deployerAddress) {
                try {
                    const tx = await (await token.setPrecrime(localContractInstance.address)).wait();
                    console.log(`✅ [${tooling.network.name}] setPrecrime`);
                    console.log(` tx: ${tx.transactionHash}`);
                } catch (e) {
                    console.log(`❌ [${tooling.network.name}] setPrecrime`);
                }
            } else {
                console.log(`Owner is ${owner}`);
                console.log(`Deployer is ${deployerAddress}`);
                console.log(
                    `[${tooling.network.name}] Skipping setPrecrime as token owner is not deployer. Use lzGnosisConfigure task to schedule a gnosis transaction to setPrecrime`
                );
            }
        } else {
            console.log(`[${tooling.network.name}] Already set to ${localContractInstance.address}`);
        }

        const owner = sourceLzDeployementConfig.owner

        console.log(`[${tooling.network.name}] Changing owner of ${localContractInstance.address} to ${owner}...`);

        if ((await localContractInstance.owner()) !== owner) {
            try {
                const tx = await localContractInstance.transferOwnership(owner);
                console.log(`[${tooling.network.name}] Transaction: ${tx.hash}`);
                await tx.wait();
            } catch {
                console.log(`[${tooling.network.name}] Failed to change owner of ${localContractInstance.address} to ${owner}...`);
            }
        } else {
            console.log(`[${tooling.network.name}] Owner is already ${owner}...`);
        }
    }
};
