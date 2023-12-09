const fs = require("fs");
const { BigNumber } = require("ethers");
const { task } = require("hardhat/config");
const { getAddress, getCauldron, WAD, loadConfig, getCauldronInformation, printCauldronInformation } = require("../utils/toolkit");

module.exports = async function (taskArgs, hre) {
  const { getContractAt, getChainIdByNetworkName, changeNetwork } = hre;
  const foundry = hre.userConfig.foundry;

  console.log(`Using network ${hre.network.name}`);
  const config = loadConfig(hre.network.name);
  console.log(`Retrieving cauldron information...`);
  const cauldron = await getCauldronInformation(hre, config, taskArgs.cauldron);

  printCauldronInformation(cauldron);
};
