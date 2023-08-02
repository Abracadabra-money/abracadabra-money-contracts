
module.exports = async function (taskArgs, hre) {
	const { getContract, changeNetwork, getLzChainIdByNetworkName } = hre;
	changeNetwork(taskArgs.network);

	const localChainId = getChainIdByNetworkName(taskArgs.network);
	const contract = await getContract(taskArgs.contract, localChainId)
	const dstChainId = getLzChainIdByNetworkName(taskArgs.targetNetwork);

	const currentMinGas = await contract.minDstGasLookup(dstChainId, taskArgs.packetType);
	if (!currentMinGas.eq(taskArgs.minGas)) {
		const tx = await contract.setMinDstGas(dstChainId, taskArgs.packetType, taskArgs.minGas)
		console.log(`[${hre.network.name}] setMinDstGas tx hash ${tx.hash}`)
		await tx.wait()
	} else {
		console.log(`[${hre.network.name}] setMinDstGas already set to ${taskArgs.minGas}`)
	}
}