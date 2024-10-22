import {ethers} from "ethers";
import {calculateChecksum} from "../utils/gnosis";
import fs from "fs";
import {confirm} from "@inquirer/prompts";
import type {NetworkName, TaskArgs, TaskArgValue, TaskFunction, TaskMeta} from "../../types";
import type {Tooling} from "../../tooling";
import {lz} from "../utils/lz";
import {transferAmountStringToWei} from "../utils";
import type { IERC20 } from "../../contracts";
import chalk from "chalk";

export const meta: TaskMeta = {
    name: "lz/bridge",
    description: "Bridge tokens between networks",
    options: {
        from: {
            type: "string",
            description: "Network to bridge from",
            required: true,
        },
        to: {
            type: "string",
            description: "Network to bridge to",
            required: true,
        },
        gnosis: {
            type: "string",
            description: "Gnosis address to use to create a batch file for",
            required: false,
        },
        recipient: {
            type: "string",
            description: "Recipient address",
        },
        token: {
            type: "string",
            required: true,
            description: "Token to bridge",
            choices: ["mim", "spell", "bspell"],
            transform: (value: TaskArgValue) => (value as string).toUpperCase(),
        },
        amount: {
            type: "string",
            description: "Amount to bridge (in token units ex: 100eth, default is wei)",
            required: true,
            transform: transferAmountStringToWei,
        },
        useWrapper: {
            type: "boolean",
            description: "Use OFTWrapper contract",
            required: false,
        },
        feeMultiplier: {
            type: "string",
            description: "Fee multiplier for layerzero endpoint fees",
            required: false,
        },
    },
};

const defaultBatch = Object.freeze({
    version: "1.0",
    chainId: "",
    createdAt: 0,
    meta: {},
    transactions: [],
});

const defaultApprove = Object.freeze({
    to: "",
    value: "0",
    data: null,
    contractMethod: {
        inputs: [
            {
                internalType: "address",
                name: "_spender",
                type: "address",
            },
            {
                name: "_amount",
                type: "uint256",
                internalType: "uint256",
            },
        ],
        name: "approve",
        payable: false,
    },
    contractInputsValues: {
        _spender: "",
        _amount: "",
    },
});

const defaultBridge = Object.freeze({
    to: "",
    value: "0",
    data: null,
    contractMethod: {
        inputs: [
            {
                name: "_from",
                type: "address",
                internalType: "address",
            },
            {
                name: "_dstChainId",
                type: "uint16",
                internalType: "uint16",
            },
            {
                name: "_toAddress",
                type: "bytes32",
                internalType: "bytes32",
            },
            {
                name: "_amount",
                type: "uint256",
                internalType: "uint256",
            },
            {
                name: "_callParams",
                type: "tuple",
                components: [
                    {
                        name: "refundAddress",
                        type: "address",
                        internalType: "address payable",
                    },
                    {
                        name: "zroPaymentAddress",
                        type: "address",
                        internalType: "address",
                    },
                    {
                        name: "adapterParams",
                        type: "bytes",
                        internalType: "bytes",
                    },
                ],
                internalType: "struct ILzCommonOFT.LzCallParams",
            },
        ],
        name: "sendFrom",
        payable: true,
    },
    contractInputsValues: {
        _from: "",
        _dstChainId: "",
        _toAddress: "",
        _amount: "",
        _callParams: "",
    },
});

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    tooling.changeNetwork(taskArgs.from as NetworkName);

    const remoteLzChainId = tooling.getLzChainIdByName(taskArgs.to as NetworkName);
    const gnosisAddress = taskArgs.gnosis;

    const tokenName = taskArgs.token as string;
    const lzDeployementConfig = await lz.getDeployementConfig(tooling, tokenName, taskArgs.from as NetworkName);

    if (taskArgs.useWrapper && !lzDeployementConfig.useWrapper) {
        console.error(`No wrapper contract for ${tokenName}`);
        process.exit(1);
    }

    let deployer = await tooling.getOrLoadDeployer();
    let deployerAddress;

    if (gnosisAddress) {
        deployerAddress = gnosisAddress;
        console.log(`Using gnosis address: ${gnosisAddress}`);
    } else {
        deployerAddress = await deployer.getAddress();
    }

    const recipient = taskArgs.recipient || deployerAddress;
    const localChainId = tooling.getChainIdByName(taskArgs.from as NetworkName);
    const toAddressBytes = ethers.AbiCoder.defaultAbiCoder().encode(["address"], [recipient]);
    const amount = BigInt(taskArgs.amount as string);

    if (taskArgs.from === taskArgs.to) {
        console.error("Cannot bridge to the same network");
        process.exit(1);
    }

    const localContractInstance = taskArgs.useWrapper
        ? await tooling.getContract(lzDeployementConfig.oftWrapper, localChainId)
        : await tooling.getContract(lzDeployementConfig.oft, localChainId);

    const packetType = 0;
    const messageVersion = 1;
    const minGas = await localContractInstance.minDstGasLookup(remoteLzChainId, packetType);

    console.log("minGas type:", typeof minGas, "minGas value:", minGas);

    if (minGas === 0n) {
        console.error(`minGas is 0, minDstGasLookup not set for destination chain ${remoteLzChainId}`);
        process.exit(1);
    }

    console.log(`minGas: ${minGas}`);
    const adapterParams = ethers.solidityPacked(["uint16", "uint256"], [messageVersion, minGas]);
    let fees;

    console.log(`⏳ Quoting fees...`);
    if (taskArgs.useWrapper) {
        fees = (await localContractInstance.estimateSendFeeV2(remoteLzChainId, toAddressBytes, amount, adapterParams))[0];
    } else {
        fees = (await localContractInstance.estimateSendFee(remoteLzChainId, toAddressBytes, amount, false, adapterParams))[0];
    }

    if (taskArgs.feeMultiplier) {
        fees = fees.mul(taskArgs.feeMultiplier);
    }

    console.log(`fees (wei): ${fees} / (eth): ${ethers.formatEther(fees.toString())}`);

    let confirmed = true;

    if (!gnosisAddress) {
        confirmed = await confirm({
            default: false,
            message: `This is going to: \n\n- Send ${ethers.formatEther(amount.toString())} ${tokenName} from ${taskArgs.from} to ${
                taskArgs.to
            } \n- Fees: ${ethers.formatEther(fees.toString())} ${taskArgs.useWrapper ? "\n- Using Wrapper" : ""}\n${
                taskArgs.feeMultiplier ? `- Fee Multiplier: ${taskArgs.feeMultiplier}x\n\n` : "\n"
            }Are you sure?`,
        });

        if (!confirmed) {
            process.exit(0);
        }
    }

    const batch = JSON.parse(JSON.stringify(defaultBatch));
    batch.chainId = localChainId.toString();

    if (lzDeployementConfig.isNative) {
        const tokenContract = await tooling.getContractAt("IERC20", lzDeployementConfig.token);
        const allowance = await tokenContract.connect(deployer).allowance(deployerAddress, await localContractInstance.getAddress());

        if (allowance < amount) {
            if (gnosisAddress) {
                console.log(` -> approve ${amount} ${tokenName}`);
                let tx = JSON.parse(JSON.stringify(defaultApprove));
                tx.to = await tokenContract.getAddress();
                tx.contractInputsValues._spender = await localContractInstance.getAddress();
                tx.contractInputsValues._amount = amount.toString();
                batch.transactions.push(tx);
            } else {
                console.log(`Approving ${tokenName}...`);
                await (await tokenContract.connect(deployer).approve(await localContractInstance.getAddress(), ethers.MaxUint256)).wait();
            }
        }
    }

    tooling.changeNetwork(taskArgs.from as NetworkName);

    console.log(`⏳ Sending tokens [${tooling.network.name}] sendTokens() to OFT @ LZ chainId[${remoteLzChainId}]`);
    let tx;

    if (taskArgs.useWrapper) {
        tx = await localContractInstance.connect(deployer).sendProxyOFTV2(
            remoteLzChainId,
            toAddressBytes,
            amount,
            [deployerAddress, ethers.ZeroAddress, adapterParams],
            {value: fees}
        );
        await tx.wait();
    } else {
        if (gnosisAddress) {
            console.log(` -> sendFrom ${amount} ${tokenName}`);
            let tx = JSON.parse(JSON.stringify(defaultBridge));
            tx.to = await localContractInstance.getAddress();
            tx.contractInputsValues._from = deployerAddress;
            tx.contractInputsValues._dstChainId = remoteLzChainId.toString();
            tx.contractInputsValues._toAddress = toAddressBytes;
            tx.contractInputsValues._amount = amount.toString();
            const calldata = JSON.stringify([deployerAddress, ethers.ZeroAddress, adapterParams]);
            tx.contractInputsValues._callParams = calldata;
            batch.transactions.push(tx);
        } else {
            tx = await localContractInstance.connect(deployer).sendFrom(
                deployerAddress,
                remoteLzChainId,
                toAddressBytes,
                amount,
                [deployerAddress, ethers.ZeroAddress, adapterParams],
                {value: fees}
            );
            await tx.wait();
        }
    }

    if (gnosisAddress) {
        batch.meta.checksum = calculateChecksum(batch);
        const content = JSON.stringify(batch, null, 4);
        const output = `${tooling.config.projectRoot}/${tooling.config.foundry.out}/transfer-${gnosisAddress}.json`;
        fs.writeFileSync(output, content, "utf8");
        console.log(`Batch file written to ${output}`);
    } else {
        console.log(`✅ Sent. https://layerzeroscan.com/tx/${tx.hash}`);
    }
};
