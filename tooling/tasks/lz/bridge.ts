import { BigNumber, ethers } from 'ethers';
import { calculateChecksum } from '../utils/gnosis';
import fs from 'fs';
import { confirm } from '@inquirer/prompts';
import { wrapperDeploymentNamePerNetwork, tokenDeploymentNamePerNetwork, spellTokenDeploymentNamePerNetwork } from '../utils/lz';
import type { TaskArgs, TaskFunction, TaskMeta, Tooling } from '../../types';

export const meta: TaskMeta = {
    name: 'lz:bridge',
    description: 'Bridge tokens between networks',
    options: {
        from: {
            type: 'string',
            description: 'Network to bridge from',
            required: true
        },
        to: {
            type: 'string',
            description: 'Network to bridge to',
            required: true
        },
        gnosis: {
            type: 'string',
            description: 'Gnosis address to use to create a batch file for',
            required: false
        },
        recipient: {
            type: 'string',
            description: 'Recipient address'
        },
        token: {
            type: 'string',
            required: true,
            description: 'Token to bridge',
            choices: ['mim', 'spell']
        },
        amount: {
            type: 'string',
            description: 'Amount to bridge in wei',
            required: true
        },
        useWrapper: {
            type: 'boolean',
            description: 'Use OFTWrapper contract',
            required: false
        },
        feeMultiplier: {
            type: 'string',
            description: 'Fee multiplier for layerzero endpoint fees',
            required: false
        },
    },
};

const defaultBatch = Object.freeze({
    version: '1.0',
    chainId: '',
    createdAt: 0,
    meta: {},
    transactions: [],
});

const defaultApprove = Object.freeze({
    to: '',
    value: '0',
    data: null,
    contractMethod: {
        inputs: [
            {
                internalType: 'address',
                name: '_spender',
                type: 'address',
            },
            {
                name: '_amount',
                type: 'uint256',
                internalType: 'uint256',
            },
        ],
        name: 'approve',
        payable: false,
    },
    contractInputsValues: {
        _spender: '',
        _amount: '',
    },
});

const defaultBridge = Object.freeze({
    to: '',
    value: '0',
    data: null,
    contractMethod: {
        inputs: [
            {
                name: '_from',
                type: 'address',
                internalType: 'address',
            },
            {
                name: '_dstChainId',
                type: 'uint16',
                internalType: 'uint16',
            },
            {
                name: '_toAddress',
                type: 'bytes32',
                internalType: 'bytes32',
            },
            {
                name: '_amount',
                type: 'uint256',
                internalType: 'uint256',
            },
            {
                name: '_callParams',
                type: 'tuple',
                components: [
                    {
                        name: 'refundAddress',
                        type: 'address',
                        internalType: 'address payable',
                    },
                    {
                        name: 'zroPaymentAddress',
                        type: 'address',
                        internalType: 'address',
                    },
                    {
                        name: 'adapterParams',
                        type: 'bytes',
                        internalType: 'bytes',
                    },
                ],
                internalType: 'struct ILzCommonOFT.LzCallParams',
            },
        ],
        name: 'sendFrom',
        payable: true,
    },
    contractInputsValues: {
        _from: '',
        _dstChainId: '',
        _toAddress: '',
        _amount: '',
        _callParams: '',
    },
});


export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    tooling.changeNetwork(taskArgs.from as string);

    const remoteLzChainId = tooling.getLzChainIdByNetworkName(taskArgs.to as string);
    const gnosisAddress = taskArgs.gnosis;
    const token = taskArgs.token;
    let deploymentNamePerNetwork = tokenDeploymentNamePerNetwork;
    let tokenName: string;
    let mainnetTokenContract: ethers.Contract;

    if (token === 'mim') {
        deploymentNamePerNetwork = tokenDeploymentNamePerNetwork;
        tokenName = 'MIM';
        mainnetTokenContract = await tooling.getContractAt('IERC20', '0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3');
    } else if (token === 'spell') {
        deploymentNamePerNetwork = spellTokenDeploymentNamePerNetwork;
        tokenName = 'SPELL';
        mainnetTokenContract = await tooling.getContractAt('IERC20', '0x090185f2135308BaD17527004364eBcC2D37e5F6');
    } else {
        console.error("Invalid token. Please use 'mim' or 'spell'");
        process.exit(1);
    }

    if (token === 'spell' && taskArgs.useWrapper) {
        console.error('No wrappers for spell');
        process.exit(1);
    }

    let deployerAddress;

    if (gnosisAddress) {
        deployerAddress = gnosisAddress;
        console.log(`Using gnosis address: ${gnosisAddress}`);
    } else {
        deployerAddress = await (await tooling.getDeployer()).getAddress();
    }

    const recipient = taskArgs.recipient || deployerAddress;
    const localChainId = tooling.getChainIdByNetworkName(taskArgs.from as string);
    const toAddressBytes = ethers.utils.defaultAbiCoder.encode(['address'], [recipient]);
    const amount = BigNumber.from(taskArgs.amount);

    if (taskArgs.from === taskArgs.to) {
        console.error('Cannot bridge to the same network');
        process.exit(1);
    }

    let localContractInstance;

    if (taskArgs.useWrapper) {
        if (!wrapperDeploymentNamePerNetwork[taskArgs.from as string]) {
            console.error(`No wrapper contract for ${taskArgs.from}`);
            process.exit(1);
        }
        localContractInstance = await tooling.getContract(wrapperDeploymentNamePerNetwork[taskArgs.from as string], localChainId);
    } else {
        localContractInstance = await tooling.getContract(deploymentNamePerNetwork[taskArgs.from as string], localChainId);
    }

    const packetType = 0;
    const messageVersion = 1;
    const minGas = await localContractInstance.minDstGasLookup(remoteLzChainId, packetType);

    if (minGas.eq(0)) {
        console.error(`minGas is 0, minDstGasLookup not set for destination chain ${remoteLzChainId}`);
        process.exit(1);
    }

    console.log(`minGas: ${minGas}`);
    const adapterParams = ethers.utils.solidityPack(['uint16', 'uint256'], [messageVersion, minGas]);
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

    console.log(`fees (wei): ${fees} / (eth): ${ethers.utils.formatEther(fees)}`);

    let confirmed = true;

    if (!gnosisAddress) {
        confirmed = await confirm({
            default: false,
            message: `This is going to: \n\n- Send ${ethers.utils.formatEther(amount)} ${tokenName} from ${taskArgs.from} to ${taskArgs.to} \n- Fees: ${ethers.utils.formatEther(fees)} ${taskArgs.useWrapper ? '\n- Using Wrapper' : ''}\n${taskArgs.feeMultiplier ? `- Fee Multiplier: ${taskArgs.feeMultiplier}x\n\n` : '\n'}Are you sure?`,
        });

        if (!confirmed) {
            process.exit(0);
        }
    }

    const batch = JSON.parse(JSON.stringify(defaultBatch));
    batch.chainId = localChainId.toString();

    if (taskArgs.from === 'mainnet') {
        const allowance = await mainnetTokenContract.allowance(deployerAddress, localContractInstance.address);

        if (allowance.lt(amount)) {
            if (gnosisAddress) {
                console.log(` -> approve ${amount} ${tokenName}`);
                let tx = JSON.parse(JSON.stringify(defaultApprove));
                tx.to = mainnetTokenContract.address;
                tx.contractInputsValues._spender = localContractInstance.address.toString();
                tx.contractInputsValues._amount = amount.toString();
                batch.transactions.push(tx);
            } else {
                console.log(`Approving ${tokenName}...`);
                await (await mainnetTokenContract.approve(localContractInstance.address, ethers.constants.MaxUint256)).wait();
            }
        }
    }

    tooling.changeNetwork(taskArgs.from as string);

    console.log(`⏳ Sending tokens [${tooling.network.name}] sendTokens() to OFT @ LZ chainId[${remoteLzChainId}]`);
    let tx;

    if (taskArgs.useWrapper) {
        tx = await (
            await localContractInstance.sendProxyOFTV2(
                remoteLzChainId,
                toAddressBytes,
                amount,
                [deployerAddress, ethers.constants.AddressZero, adapterParams],
                { value: fees }
            )
        ).wait();
    } else {
        if (gnosisAddress) {
            console.log(` -> sendFrom ${amount} ${tokenName}`);
            let tx = JSON.parse(JSON.stringify(defaultBridge));
            tx.to = localContractInstance.address;
            tx.contractInputsValues._from = deployerAddress;
            tx.contractInputsValues._dstChainId = remoteLzChainId.toString();
            tx.contractInputsValues._toAddress = toAddressBytes;
            tx.contractInputsValues._amount = amount.toString();
            const calldata = JSON.stringify([deployerAddress, ethers.constants.AddressZero, adapterParams]);
            tx.contractInputsValues._callParams = calldata;
            batch.transactions.push(tx);
        } else {
            tx = await (
                await localContractInstance.sendFrom(
                    deployerAddress,
                    remoteLzChainId,
                    toAddressBytes,
                    amount,
                    [deployerAddress, ethers.constants.AddressZero, adapterParams],
                    { value: fees }
                )
            ).wait();
        }
    }

    if (gnosisAddress) {
        batch.meta.checksum = calculateChecksum(batch);
        const content = JSON.stringify(batch, null, 4);
        const output = `${tooling.projectRoot}/${tooling.config.foundry.out}/transfer-${gnosisAddress}.json`;
        fs.writeFileSync(output, content, 'utf8');
        console.log(`Batch file written to ${output}`);
    } else {
        console.log(`✅ Sent. https://layerzeroscan.com/tx/${tx.transactionHash}`);
    }
};
