const CHAIN_ID = require("./chainIds.json")

module.exports = async function (taskArgs, hre) {
	const { foundryDeployments } = hre;

	const contract = await foundryDeployments.get(taskArgs.contract)
	const dstChainId = CHAIN_ID[taskArgs.targetNetwork]
	const tx = await contract.setMinDstGas(dstChainId, taskArgs.packetType, taskArgs.minGas)

	console.log(`[${hre.network.name}] setMinDstGas tx hash ${tx.hash}`)
	await tx.wait()
}