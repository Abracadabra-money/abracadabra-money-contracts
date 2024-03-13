const { tokenDeploymentNamePerNetwork, spellTokenDeploymentNamePerNetwork, getApplicationConfig } = require("../utils/lz");

module.exports = async (taskArgs, hre) => {
	const { getContract } = hre;

	let deploymentNamePerNetwork;
	const token = taskArgs.token;

	if (token == "mim") {
        deploymentNamePerNetwork = tokenDeploymentNamePerNetwork;
    } else if (token == "spell") {
        deploymentNamePerNetwork = spellTokenDeploymentNamePerNetwork;
    } else {
        console.error("Invalid token. Please use 'mim' or 'spell'");
        process.exit(1);
    }


	const network = hre.network.name;
	let toNetworks = taskArgs.to.split(",");

	if (toNetworks.length == 1 && toNetworks[0] == "all") {
		toNetworks = hre.getAllNetworksLzMimSupported();
	}

	const localChainId = getChainIdByNetworkName(network);

	const oft = await getContract(deploymentNamePerNetwork[network], localChainId);
	if (!oft) {
		console.error(`Deployment information isn't found for ${network}`);
		return;
	}

	const oftAddress = oft.address;;
	const { addresses } = require(`../../config/${network}.json`);

	let endpointAddress = addresses.find(a => a.key === "LZendpoint");
	if (!endpointAddress) {
		console.log(`No LZendpoint address found for ${network}`);
		process.exit(1);
	}

	endpointAddress = endpointAddress.value;
	const endpoint = await getContractAt("ILzEndpoint", endpointAddress);

	const appConfig = await endpoint.uaConfigLookup(oftAddress);
	const sendVersion = appConfig.sendVersion;
	const receiveVersion = appConfig.receiveVersion;
	const sendLibraryAddress = sendVersion === 0 ? await endpoint.defaultSendLibrary() : appConfig.sendLibrary;
	const sendLibrary = await getContractAt(
		"ILzUltraLightNodeV2",
		sendLibraryAddress
	);

	let receiveLibrary;

	if (sendVersion !== receiveVersion) {
		const receiveLibraryAddress = receiveVersion === 0 ? await endpoint.defaultReceiveLibraryAddress() : appConfig.receiveLibraryAddress;
		receiveLibrary = await getContractAt(
			"ILzUltraLightNodeV2",
			receiveLibraryAddress
		);
	}

	const remoteConfigs = [];
	for (let toNetwork of toNetworks) {
		if (network === toNetwork) {
			continue;
		}

		const config = await getApplicationConfig(hre, toNetwork, sendLibrary, receiveLibrary, oftAddress);
		remoteConfigs.push(config);
	}


	console.log("Network            ", network);
	console.log("Application address", oftAddress);
	console.log("Send version       ", sendVersion);
	console.log("Receive version    ", receiveVersion);
	console.table(remoteConfigs);
}
