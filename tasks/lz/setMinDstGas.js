const CHAIN_ID = require("./chainIds.json")

module.exports = async function (taskArgs, hre) {
	const { foundryDeployments, changeNetwork } = hre;
	changeNetwork(taskArgs.network);

	const contract = await foundryDeployments.getContract(taskArgs.contract)
	const dstChainId = CHAIN_ID[taskArgs.targetNetwork]

	const currentMinGas = await contract.minDstGasLookup(dstChainId, taskArgs.packetType);
	if (!currentMinGas.eq(taskArgs.minGas)) {
		const tx = await contract.setMinDstGas(dstChainId, taskArgs.packetType, taskArgs.minGas)
		console.log(`[${hre.network.name}] setMinDstGas tx hash ${tx.hash}`)
		await tx.wait()
	} else {
		console.log(`[${hre.network.name}] setMinDstGas already set to ${taskArgs.minGas}`)
	}
}