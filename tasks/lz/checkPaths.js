module.exports = async function (taskArgs, hre) {
  const { changeNetwork, getContractAt } = hre;

  taskArgs.networks = Object.keys(hre.config.networks);

  for (const fromNetwork of taskArgs.networks) {
    changeNetwork(fromNetwork);

    const config = require(`../../config/${fromNetwork}.json`);

    let endpoint = config.addresses.find((a) => a.key === "LZendpoint");
    if (!endpoint) {
      console.log(`No LZendpoint address found for ${network}`);
      process.exit(1);
    }

    const endpointContract = await getContractAt("ILzEndpoint", endpoint.value);

    for (const toNetwork of taskArgs.networks) {
      if (fromNetwork == toNetwork) {
        continue;
      }

      console.log(`Checking ${fromNetwork} -> ${toNetwork}`);
      const sendLibraryAddress = await endpointContract.defaultSendLibrary();
      const sendLibrary = await getContractAt(
        "ILzUltraLightNodeV2",
        sendLibraryAddress
      );

      const networkConfig = getNetworkConfigByName(toNetwork);
      const config = await sendLibrary.defaultAppConfig(
        networkConfig.lzChainId
      );

      if (config.relayer == "0x") {
        console.log(`No path for ${fromNetwork} -> ${toNetwork}`);
      }
    }
  }
};
