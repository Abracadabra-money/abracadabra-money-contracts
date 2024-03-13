const { BigNumber } = require("ethers");
const inquirer = require('inquirer');
const { calculateChecksum } = require("../utils/gnosis");
const fs = require('fs');
const { wrapperDeploymentNamePerNetwork, tokenDeploymentNamePerNetwork, spellTokenDeploymentNamePerNetwork } = require("../utils/lz");

module.exports = async function (taskArgs, hre) {
    const { changeNetwork, getChainIdByNetworkName, getContract, getContractAt, getDeployer, getLzChainIdByNetworkName } = hre;
    const foundry = hre.userConfig.foundry;

    changeNetwork(taskArgs.from);

    const remoteLzChainId = getLzChainIdByNetworkName(taskArgs.to);
    const gnosisAddress = taskArgs.gnosis;
    const recipient = taskArgs.recipient;
    const token = taskArgs.token;
    let deploymentNamePerNetwork = tokenDeploymentNamePerNetwork;
    let tokenName;
    let mainnetTokenContract;

    if (token == "mim") {
        deploymentNamePerNetwork = tokenDeploymentNamePerNetwork;
        tokenName = "MIM";
        mainnetTokenContract = await getContractAt("IERC20", "0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3");
    } else if (token == "spell") {
        deploymentNamePerNetwork = spellTokenDeploymentNamePerNetwork;
        tokenName = "SPELL";
        mainnetTokenContract = await getContractAt("IERC20", "0x090185f2135308BaD17527004364eBcC2D37e5F6");
    } else {
        console.error("Invalid token. Please use 'mim' or 'spell'");
        process.exit(1);
    }

    if (token == "spell" && taskArgs.useWrapper) {
        console.error("No wrappers for SPELL");
        process.exit(1);
    }

    let deployer = await getDeployer();

    if (gnosisAddress) {
        deployer = {
            address: gnosisAddress
        };
        console.log(`Using gnosis address: ${gnosisAddress}`);
    }


    const localChainId = getChainIdByNetworkName(taskArgs.from);
    let localContractInstance;
    const toAddressBytes = ethers.utils.defaultAbiCoder.encode(['address'], [recipient])
    const amount = BigNumber.from(taskArgs.amount);

    if (taskArgs.from == taskArgs.to) {
        console.error("Cannot bridge to the same network");
        process.exit(1);
    }

    if (taskArgs.useWrapper) {
        if (!wrapperDeploymentNamePerNetwork[taskArgs.from]) {
            console.error(`No wrapper contract for ${taskArgs.from}`);
            process.exit(1);
        }
        localContractInstance = await getContract(wrapperDeploymentNamePerNetwork[taskArgs.from], localChainId);
    } else {
        localContractInstance = await getContract(deploymentNamePerNetwork[taskArgs.from], localChainId);
    }


    // quote fee with default adapterParams
    const packetType = 0;
    const messageVersion = 1;
    const minGas = await localContractInstance.minDstGasLookup(remoteLzChainId, packetType);

    if (minGas.eq(0)) {
        console.error(`minGas is 0, minDstGasLookup not set for destination chain ${remoteLzChainId}`);
        process.exit(1);
    }

    console.log(`minGas: ${minGas}`);
    const adapterParams = ethers.utils.solidityPack(["uint16", "uint256"], [messageVersion, minGas]) // default adapterParams example
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

    console.log(`fees (wei): ${fees} / (eth): ${ethers.utils.formatEther(fees)}`)

    let answers;

    if (!gnosisAddress) {
        answers = await inquirer.prompt([
            {
                name: 'confirm',
                type: 'confirm',
                default: false,
                message: `This is going to: \n\n- Send ${ethers.utils.formatEther(amount)} ${tokenName} from ${taskArgs.from} to ${taskArgs.to} \n- Fees: ${ethers.utils.formatEther(fees)} ${taskArgs.useWrapper ? "\n- Using Wrapper" : ""}\n${taskArgs.feeMultiplier ? `- Fee Multiplier: ${taskArgs.feeMultiplier}x\n\n` : "\n"}Are you sure?`,
            }
        ]);
    }

    const defaultBatch = Object.freeze({
        version: "1.0",
        chainId: "",
        createdAt: 0,
        meta: {},
        transactions: [

        ]
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
                    type: "address"
                },
                {
                    name: "_amount",
                    type: "uint256",
                    internalType: "uint256"
                }
            ],
            name: "approve",
            payable: false
        },
        contractInputsValues: {
            _spender: "",
            _amount: ""
        }
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
                    internalType: "address"
                },
                {
                    name: "_dstChainId",
                    type: "uint16",
                    internalType: "uint16"
                },
                {
                    name: "_toAddress",
                    type: "bytes32",
                    internalType: "bytes32"
                },
                {
                    name: "_amount",
                    type: "uint256",
                    internalType: "uint256"
                },
                {
                    name: "_callParams",
                    type: "tuple",
                    components: [
                        {
                            name: "refundAddress",
                            type: "address",
                            internalType: "address payable"
                        },
                        {
                            name: "zroPaymentAddress",
                            type: "address",
                            internalType: "address"
                        },
                        {
                            name: "adapterParams",
                            type: "bytes",
                            internalType: "bytes"
                        }
                    ],
                    internalType: "struct ILzCommonOFT.LzCallParams"
                }
            ],
            name: "sendFrom",
            payable: true
        },
        contractInputsValues: {
            _from: "",
            _dstChainId: "",
            _toAddress: "",
            _amount: "",
            _callParams: ""
        }
    });

    if (!gnosisAddress) {
        if (answers.confirm === false) {
            process.exit(0);
        }
    }

    const batch = JSON.parse(JSON.stringify(defaultBatch));
    batch.chainId = localChainId.toString();

    if (taskArgs.from === "mainnet") {
        const allowance = await mainnetTokenContract.allowance(deployer.address, localContractInstance.address);

        if (allowance.lt(amount)) {
            if (gnosisAddress) {
                console.log(` -> approve ${amount} ${tokenName}`);
                let tx = JSON.parse(JSON.stringify(defaultApprove));
                tx.to = mim.address;
                tx.contractInputsValues._spender = localContractInstance.address.toString();
                tx.contractInputsValues._amount = amount.toString();
                batch.transactions.push(tx);
            } else {
                console.log(`Approving ${tokenName}...`);
                await (await mainnetTokenContract.approve(localContractInstance.address, ethers.constants.MaxUint256)).wait();
            }
        }
    }

    changeNetwork(taskArgs.from);

    console.log(`⏳ Sending tokens [${hre.network.name}] sendTokens() to OFT @ LZ chainId[${remoteLzChainId}]`);
    let tx;

    if (taskArgs.useWrapper) {
        tx = await (
            await localContractInstance.sendProxyOFTV2(
                remoteLzChainId, // remote LayerZero chainId
                toAddressBytes, // 'to' address to send tokens
                amount, // amount of tokens to send (in wei)
                [deployer.address, ethers.constants.AddressZero, adapterParams],
                { value: fees }
            )
        ).wait();
    } else {
        if (gnosisAddress) {
            console.log(` -> sendFrom ${amount} ${tokenName}`);
            let tx = JSON.parse(JSON.stringify(defaultBridge));
            tx.to = localContractInstance.address;
            tx.contractInputsValues._from = deployer.address;
            tx.contractInputsValues._dstChainId = remoteLzChainId.toString();
            tx.contractInputsValues._toAddress = toAddressBytes;
            tx.contractInputsValues._amount = amount.toString();
            const calldata = JSON.stringify([deployer.address, ethers.constants.AddressZero, adapterParams]);
            tx.contractInputsValues._callParams = calldata;
            batch.transactions.push(tx);
        } else {
            tx = await (
                await localContractInstance.sendFrom(
                    deployer.address, // 'from' address to send tokens
                    remoteLzChainId, // remote LayerZero chainId
                    toAddressBytes, // 'to' address to send tokens
                    amount, // amount of tokens to send (in wei)
                    [deployer.address, ethers.constants.AddressZero, adapterParams],
                    { value: fees }
                )
            ).wait();
        }
    }

    if (gnosisAddress) {
        batch.meta.checksum = calculateChecksum(hre.ethers, batch);
        content = JSON.stringify(batch, null, 4);
        const output = `${hre.config.paths.root}/${foundry.out}/transfer-${gnosisAddress}.json`
        fs.writeFileSync(output, content, 'utf8');
        console.log(`Batch file written to ${output}`);
    } else {
        console.log(`✅ Sent. https://layerzeroscan.com/tx/${tx.transactionHash}`)
    }
}