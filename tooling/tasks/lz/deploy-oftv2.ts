import type {NetworkName, TaskArgs, TaskArgValue, TaskFunction, TaskMeta} from "../../types";
import type {Tooling} from "../../tooling";
import {exec, showError} from "../utils";
import {lz} from "../utils/lz";
import {utils} from "ethers";

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
            choices: ["deploy", "configure", "precrime:deploy", "precrime:configure", "change-owners"],
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

    if (taskArgs.stage === "precrime:deploy") {
        let script = "";
        if (tokenName === "MIM") {
            script = "PreCrime";
        } else if (tokenName === "SPELL") {
            script = "SpellPreCrime";
        } else if (tokenName === "BSPELL") {
            script = "BoundSpellPreCrime";
        }

        await exec(`bun run clean`);
        await exec(`bun run build`);
        await exec(`bun task forge-deploy-multichain --script ${script} --broadcast --verify --no-confirm ${networks.join(" ")}`);
    }

    if (taskArgs.stage === "precrime:configure") {
        for (const srcNetwork of networks) {
            tooling.changeNetwork(srcNetwork);

            const sourceLzDeployementConfig = await lz.getDeployementConfig(tooling, tokenName, srcNetwork);

            // get local contract
            const localContractInstance = await tooling.getContract(sourceLzDeployementConfig.precrime, tooling.network.config.chainId);
            let remoteChainIDs = [];
            let remotePrecrimeAddresses = [];

            for (const targetNetwork of supportedNetworks) {
                if (targetNetwork === srcNetwork) continue;

                const targetLzDeployementConfig = await lz.getDeployementConfig(tooling, tokenName, targetNetwork);

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
                const deployerAddress = await (await tooling.getDeployer()).getAddress();
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

            const owner = sourceLzDeployementConfig.owner;

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
    }

    if (taskArgs.stage === "change-owners") {
        const tokenName = taskArgs.token as string;
        const networks = lz.getSupportedNetworks(tokenName);

        for (const network of networks) {
            const config = lz.getDeployementConfig(tooling, tokenName, network);

            const owner = config.owner;
            const chainId = tooling.getChainIdByName(network);
            const tokenContract = await tooling.getContract(config.oft, chainId);

            console.log(`[${network}] Changing owner of ${tokenContract.address} to ${owner}...`);

            if ((await tokenContract.owner()) !== owner) {
                try {
                    const tx = await tokenContract.transferOwnership(owner);
                    console.log(`[${network}] Transaction: ${tx.hash}`);
                    await tx.wait();
                } catch (e) {
                    showError(`[${network}] Failed to change owner`, e);
                }
            } else {
                console.log(`[${network}] Owner is already ${owner}...`);
            }

            if (config.minterBurner) {
                const minterContract = await tooling.getContract(config.minterBurner, chainId);

                console.log(`[${network}] Changing owner of ${minterContract.address} to ${owner}...`);

                if ((await minterContract.owner()) !== owner) {
                    try {
                        const tx = await minterContract.transferOwnership(owner, true, false);
                        console.log(`[${network}] Transaction: ${tx.hash}`);
                        await tx.wait();
                    } catch (e) {
                        showError(`[${network}] Failed to change minter owner`, e);
                    }
                } else {
                    console.log(`[${network}] Owner is already ${owner}...`);
                }
            }
        }
    }
};
