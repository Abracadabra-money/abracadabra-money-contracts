const { BigNumber } = require("ethers");
const CHAIN_ID = require("./chainIds.json")

module.exports = async function (taskArgs, hre) {
    const { foundryDeployments, changeNetwork, getChainIdByNetworkName, getContractAt, getDeployer } = hre;

    changeNetwork(taskArgs.from);

    const remoteLzChainId = CHAIN_ID[taskArgs.to];
    const deployer = await getDeployer();

    const tokenDeploymentNamePerNetwork = {
        "mainnet": "Mainnet_ProxyOFTV2",
        "bsc": "BSC_IndirectOFTV2",
        "polygon": "Polygon_IndirectOFTV2",
        "fantom": "Fantom_IndirectOFTV2",
        "optimism": "Optimism_IndirectOFTV2",
        "arbitrum": "Arbitrum_IndirectOFTV2",
        "avalanche": "Avalanche_IndirectOFTV2",
        "moonriver": "Moonriver_IndirectOFTV2",
        "kava": "Kava_IndirectOFTV2"
    };

    const localChainId = getChainIdByNetworkName(taskArgs.from);
    const localContractInstance = await foundryDeployments.getContract(tokenDeploymentNamePerNetwork[taskArgs.from], localChainId);
    const toAddressBytes = ethers.utils.defaultAbiCoder.encode(['address'], [deployer.address])
    const amount = BigNumber.from(taskArgs.amount);

    if (taskArgs.from === "mainnet") {
        const mim = await getContractAt("IERC20", "0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3");
        const allowance = await mim.allowance(deployer.address, localContractInstance.address);

        if (allowance.lt(amount)) {
            console.log("Approving MIM...");
            await (await mim.approve(localContractInstance.address, ethers.constants.MaxUint256)).wait();
        }
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

    console.log(`⏳ Quoting fees...`);
    const fees = await localContractInstance.estimateSendFee(remoteLzChainId, toAddressBytes, amount, false, adapterParams)
    console.log(`fees[0] (wei): ${fees[0]} / (eth): ${ethers.utils.formatEther(fees[0])}`)

    changeNetwork(taskArgs.from);

    console.log(`⏳ Sending tokens [${hre.network.name}] sendTokens() to OFT @ LZ chainId[${remoteLzChainId}]`);
    let tx = await (
        await localContractInstance.sendFrom(
            deployer.address, // 'from' address to send tokens
            remoteLzChainId, // remote LayerZero chainId
            toAddressBytes, // 'to' address to send tokens
            amount, // amount of tokens to send (in wei)
            [deployer.address, ethers.constants.AddressZero, adapterParams], // flexible bytes array to indicate messaging adapter services
            { value: fees[0] }
        )
    ).wait();
    console.log(`✅ Sent. https://layerzeroscan.com/tx/${tx.transactionHash}`)
}