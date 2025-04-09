import type {NetworkName, TaskArgs, TaskArgValue, TaskFunction, TaskMeta} from "../../types";
import type {Tooling} from "../../tooling";
import {exec, showError} from "../utils";
import {lz} from "../utils/lz";
import {AbiCoder} from "ethers";
import chalk from "chalk";

export const meta: TaskMeta = {
    name: "lz/deploy-oftv2",
    description: "Deploy LayerZero contracts",
    options: {
        token: {
            type: "string",
            description: "Token to deploy",
            required: true,
            choices: ["mim"],
            transform: (value: TaskArgValue) => (value as string).toUpperCase(),
        },
        stage: {
            type: "string",
            description: "Stage to execute",
            required: true,
            choices: ["deploy", "configure", "precrime:deploy", "precrime:configure", "change-owners", "check-owners"],
        },
    },
    positionals: {
        name: "networks",
        description: "Networks to deploy and configure",
        required: false,
    },
};

const _checkNetworkArgs = (taskArgs: TaskArgs) => {
    const networks = taskArgs.networks as NetworkName[];

    if (networks.length === 0) {
        console.log("No networks specified for deployment");
        return; // Exit the function if no networks are specified
    }
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const tokenName = taskArgs.token as string;
    const networks = taskArgs.networks as NetworkName[];
    const supportedNetworks = lz.getSupportedNetworks(tokenName);
    if (taskArgs.stage === "deploy") {
        _checkNetworkArgs(taskArgs);

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
        _checkNetworkArgs(taskArgs);

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
        _checkNetworkArgs(taskArgs);

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
            await tooling.changeNetwork(srcNetwork);
            const deployer = await tooling.getOrLoadDeployer();

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

                const bytes32address = AbiCoder.defaultAbiCoder().encode(["address"], [remoteContractInstance.target]);
                remoteChainIDs.push(tooling.getLzChainIdByName(targetNetwork));
                remotePrecrimeAddresses.push(bytes32address);
            }

            try {
                const tx = await localContractInstance.connect(deployer).setRemotePrecrimeAddresses(remoteChainIDs, remotePrecrimeAddresses);
                await tx.wait();
                console.log(`✅ [${tooling.network.name}] setRemotePrecrimeAddresses`);
                console.log(` tx: ${tx.hash}`);
            } catch (e) {
                console.log(`❌ [${tooling.network.name}] setRemotePrecrimeAddresses`);
            }

            const token = await tooling.getContract(sourceLzDeployementConfig.oft, tooling.network.config.chainId);
            console.log(`Setting precrime address to ${localContractInstance.target}...`);

            if ((await token.precrime()) !== localContractInstance.target) {
                const owner = await token.owner();
                const deployerAddress = await (await tooling.getOrLoadDeployer()).getAddress();
                if (owner === deployerAddress) {
                    try {
                        const tx = await token.connect(deployer).setPrecrime(localContractInstance.target);
                        await tx.wait();
                        console.log(`✅ [${tooling.network.name}] setPrecrime`);
                        console.log(` tx: ${tx.hash}`);
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
                console.log(`[${tooling.network.name}] Already set to ${localContractInstance.target}`);
            }

            const owner = sourceLzDeployementConfig.owner;

            console.log(`[${tooling.network.name}] Changing owner of ${localContractInstance.target} to ${owner}...`);

            if ((await localContractInstance.owner()) !== owner) {
                try {
                    const tx = await localContractInstance.connect(deployer).transferOwnership(owner);
                    console.log(`[${tooling.network.name}] Transaction: ${tx.hash}`);
                    await tx.wait();
                } catch {
                    console.log(`[${tooling.network.name}] Failed to change owner of ${localContractInstance.target} to ${owner}...`);
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
            const deployer = await tooling.getOrLoadDeployer();
            console.log(`[${network}] Changing owner of ${await tokenContract.getAddress()} to ${owner}...`);

            if ((await tokenContract.owner()) !== owner) {
                try {
                    const tx = await tokenContract.connect(deployer).transferOwnership(owner);
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

                console.log(`[${network}] Changing owner of ${await minterContract.getAddress()} to ${owner}...`);

                if ((await minterContract.owner()) !== owner) {
                    try {
                        const tx = await minterContract.connect(deployer).transferOwnership(owner, true, false);
                        console.log(`[${network}] Transaction: ${tx.hash}`);
                        await tx.wait();
                    } catch (e) {
                        showError(`[${network}] Failed to change minter owner`, e);
                    }
                } else {
                    console.log(`[${network}] Owner is already ${owner}...`);
                }
            }

            const precrimeContract = await tooling.getContract(config.precrime, chainId);

            console.log(`[${network}] Changing owner of ${await precrimeContract.getAddress()} to ${owner}...`);

            if ((await precrimeContract.owner()) !== owner) {
                try {
                    const tx = await precrimeContract.connect(deployer).transferOwnership(owner);
                    console.log(`[${network}] Transaction: ${tx.hash}`);
                    await tx.wait();
                } catch (e) {
                    showError(`[${network}] Failed to change precrime owner`, e);
                }
            } else {
                console.log(`[${network}] Owner is already ${owner}...`);
            }
        }
    }

    if (taskArgs.stage === "check-owners") {
        const tokenName = taskArgs.token as string;
        const networks = lz.getSupportedNetworks(tokenName);

        for (const network of networks) {
            const config = lz.getDeployementConfig(tooling, tokenName, network);

            const expectedOwner = config.owner;
            const chainId = tooling.getChainIdByName(network);
            const tokenContract = await tooling.getContract(config.oft, chainId);

            const currentOwner = await tokenContract.owner();
            console.log(chalk.cyan(`[${network}]`));
            console.log(chalk.yellow(`OFT contract (${await tokenContract.getAddress()})`));
            console.log(`Current owner: ${chalk.green(currentOwner)}`);
            console.log(`Expected owner: ${chalk.green(expectedOwner)}`);
            console.log(`Ownership status: ${currentOwner === expectedOwner ? chalk.green("Correct") : chalk.red("Mismatch")}`);

            if (config.minterBurner) {
                const minterContract = await tooling.getContract(config.minterBurner, chainId);
                const minterOwner = await minterContract.owner();
                console.log(chalk.yellow(`MinterBurner contract (${await minterContract.getAddress()})`));
                console.log(`Current owner: ${chalk.green(minterOwner)}`);
                console.log(`Expected owner: ${chalk.green(expectedOwner)}`);
                console.log(`Ownership status: ${minterOwner === expectedOwner ? chalk.green("Correct") : chalk.red("Mismatch")}`);
            }

            const precrimeContract = await tooling.getContract(config.precrime, chainId);
            const precrimeOwner = await precrimeContract.owner();
            console.log(chalk.yellow(`Precrime contract (${await precrimeContract.getAddress()})`));
            console.log(`Current owner: ${chalk.green(precrimeOwner)}`);
            console.log(`Expected owner: ${chalk.green(expectedOwner)}`);
            console.log(`Ownership status: ${precrimeOwner === expectedOwner ? chalk.green("Correct") : chalk.red("Mismatch")}`);
            console.log();
        }
    }
};
