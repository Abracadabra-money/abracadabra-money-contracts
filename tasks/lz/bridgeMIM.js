const { BigNumber } = require("ethers");
const inquirer = require('inquirer');

module.exports = async function (taskArgs, hre) {
    const { changeNetwork, getChainIdByNetworkName, getContract, getContractAt, getDeployer, getLzChainIdByNetworkName } = hre;

    changeNetwork(taskArgs.from);

    const remoteLzChainId = getLzChainIdByNetworkName(taskArgs.to);
    const deployer = await getDeployer();

    const wrapperDeploymentNamePerNetwork = {
        "mainnet": "Mainnet_OFTWrapper",
        "bsc": "BSC_OFTWrapper",
        "polygon": "Polygon_OFTWrapper",
        "fantom": "Fantom_OFTWrapper",
        "optimism": "Optimism_OFTWrapper",
        "arbitrum": "Arbitrum_OFTWrapper",
        "avalanche": "Avalanche_OFTWrapper",
        "moonriver": "Moonriver_OFTWrapper",
        "kava": "Kava_OFTWrapper"
    };


    const tokenDeploymentNamePerNetwork = {
        "mainnet": "Mainnet_ProxyOFTV2",
        "bsc": "BSC_IndirectOFTV2",
        "polygon": "Polygon_IndirectOFTV2",
        "fantom": "Fantom_IndirectOFTV2",
        "optimism": "Optimism_IndirectOFTV2",
        "arbitrum": "Arbitrum_IndirectOFTV2",
        "avalanche": "Avalanche_IndirectOFTV2",
        "moonriver": "Moonriver_IndirectOFTV2",
        "kava": "Kava_IndirectOFTV2",
        "base": "Base_IndirectOFTV2",
        "linea": "Linea_IndirectOFTV2",
    };

    const localChainId = getChainIdByNetworkName(taskArgs.from);
    let localContractInstance;
    const toAddressBytes = ethers.utils.defaultAbiCoder.encode(['address'], [deployer.address])
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
        localContractInstance = await getContract(tokenDeploymentNamePerNetwork[taskArgs.from], localChainId);
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

    if(taskArgs.feeMultiplier) {
        fees = fees.mul(taskArgs.feeMultiplier);
    }

    console.log(`fees (wei): ${fees} / (eth): ${ethers.utils.formatEther(fees)}`)

    const answers = await inquirer.prompt([
        {
            name: 'confirm',
            type: 'confirm',
            default: false,
            message: `This is going to: \n\n- Send ${ethers.utils.formatEther(amount)} MIM from ${taskArgs.from} to ${taskArgs.to} \n- Fees: ${ethers.utils.formatEther(fees)} ${taskArgs.useWrapper ? "\n- Using Wrapper" : ""}\n${taskArgs.feeMultiplier ? `- Fee Multiplier: ${taskArgs.feeMultiplier}x\n\n` : "\n"}Are you sure?`,
        }
    ]);

    if (answers.confirm === false) {
        process.exit(0);
    }

    if (taskArgs.from === "mainnet") {
        const mim = await getContractAt("IERC20", "0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3");
        const allowance = await mim.allowance(deployer.address, localContractInstance.address);

        if (allowance.lt(amount)) {
            console.log("Approving MIM...");
            await (await mim.approve(localContractInstance.address, ethers.constants.MaxUint256)).wait();
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




    console.log(`✅ Sent. https://layerzeroscan.com/tx/${tx.transactionHash}`)
}