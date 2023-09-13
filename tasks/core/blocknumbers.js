module.exports = async function (taskArgs, hre) {
  const chainIdEnum = {
    1: "Mainnet",
    56: "BSC",
    137: "Polygon",
    250: "Fantom",
    10: "Optimism",
    42161: "Arbitrum",
    43114: "Avalanche",
    1285: "Moonriver",
    2222: "Kava",
    59144: "Linea",
    8453: "Base",
  };

  const { userConfig } = hre;
  delete userConfig.networks.ethereum;
  const networks = Object.keys(userConfig.networks).map(network => ({ name: network, chainId: userConfig.networks[network].chainId }));
  const latestBlocks = {};

  await Promise.all(networks.map(async (network) => {
    //console.log(`Querying ${network.name}...`);
    changeNetwork(network.name);
    const latestBlock = await hre.ethers.provider.getBlockNumber();
    latestBlocks[network.chainId] = latestBlock;
  }));

  await Promise.all(networks.map(async (network) => {
    console.log(`${network.name}: ${latestBlocks[network.chainId]}`);
  }));


  console.log('\nCode:\n----');
  await Promise.all(networks.map(async (network) => {
    console.log(`fork(ChainId.${chainIdEnum[network.chainId]}, ${latestBlocks[network.chainId]});`);
  }));
};

