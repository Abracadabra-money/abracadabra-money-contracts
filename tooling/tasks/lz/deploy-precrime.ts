import {$} from "bun";
import {utils} from "ethers";
import type {TaskArgs, TaskFunction, TaskMeta} from "../../types";
import {
    mimTokenDeploymentNamePerNetwork as _tokenDeploymentNamePerNetwork,
    spellTokenDeploymentNamePerNetwork as _spellTokenDeploymentNamePerNetwork,
    ownerPerNetwork,
    precrimeDeploymentNamePerNetwork as _precrimeDeploymentNamePerNetwork,
    spellPrecrimeDeploymentNamePerNetwork as _spellPrecrimeDeploymentNamePerNetwork,
} from "../utils/lz";
import type {Tooling} from "../../tooling";
import {exec} from "../utils";

export const meta: TaskMeta = {
    name: "lz/deploy-precrime",
    description: "Deploy LayerZero Precrime contracts",
    options: {
        token: {
            type: "string",
            description: "Token to deploy (mim or spell)",
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
    const networks = taskArgs.networks as string[];
    const token = taskArgs.token;
    let precrimeDeploymentNamePerNetwork: any;
    let tokenDeploymentNamePerNetwork: any;
    let script = "";

    if (token === "mim") {
        script = "PreCrime";
        tokenDeploymentNamePerNetwork = _tokenDeploymentNamePerNetwork;
        precrimeDeploymentNamePerNetwork = _precrimeDeploymentNamePerNetwork;
    } else if (token === "spell") {
        script = "SpellPreCrime";
        tokenDeploymentNamePerNetwork = _spellTokenDeploymentNamePerNetwork;
        precrimeDeploymentNamePerNetwork = _spellPrecrimeDeploymentNamePerNetwork;
    }

    await exec(`bun run clean`);
    await exec(`bun run build`);
    await exec(`bun task forge-deploy-multichain --script ${script} --broadcast --verify --no-confirm ${networks.join(" ")}`);

    const deployerAddress = await (await tooling.getDeployer()).getAddress();

    for (const srcNetwork of networks) {
        tooling.changeNetwork(srcNetwork);

        // get local contract
        const localContractInstance = await tooling.getContract(
            precrimeDeploymentNamePerNetwork[srcNetwork],
            tooling.network.config.chainId
        );
        let remoteChainIDs = [];
        let remotePrecrimeAddresses = [];

        for (const targetNetwork of Object.keys(precrimeDeploymentNamePerNetwork)) {
            if (targetNetwork === srcNetwork) continue;

            console.log(`[${srcNetwork}] Adding Precrime for ${precrimeDeploymentNamePerNetwork[targetNetwork]}`);
            const remoteChainId = tooling.getNetworkConfigByName(targetNetwork).chainId;
            const remoteContractInstance = await tooling.getContract(precrimeDeploymentNamePerNetwork[targetNetwork], remoteChainId);

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

        const token = await tooling.getContract(tokenDeploymentNamePerNetwork[srcNetwork], tooling.network.config.chainId);
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

        const owner = ownerPerNetwork[srcNetwork];

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
