module.exports = async function (taskArgs, hre) {
  const { userConfig } = hre;
  delete userConfig.networks.ethereum;
  const networks = Object.keys(userConfig.networks).map(network => ({ name: network, chainId: userConfig.networks[network].chainId }));
  const chainIdEnum = Object.keys(userConfig.networks).reduce((acc, network) => {
    const capitalizedNetwork = network.charAt(0).toUpperCase() + network.slice(1);
    return { ...acc, [userConfig.networks[network].chainId]: capitalizedNetwork };
  }, {});
  
  const latestBlocks = {};

  await Promise.all(networks.map(async (network) => {
    console.log(`Querying ${network.name}...`);
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

