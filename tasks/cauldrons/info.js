const { getCauldronInformationUsingConfig, getCauldron, WAD, loadConfig, getCauldronInformation, printCauldronInformation } = require("../utils/toolkit");
const { Table } = require("console-table-printer");

const printMastercontractInformation = (hre, networkName, address, owner) => {
  const p = new Table({
    columns: [
      { name: 'info', alignment: 'right', color: "cyan" },
      { name: 'value', alignment: 'left' }
    ],
  });

  const defaultValColors = { color: "green" };

  p.addRow({ info: "Address", value: address }, defaultValColors);

  let ownerLabelAndAddress = owner;
  const label = hre.getLabelByAddress(networkName, owner);
  if (label) {
      ownerLabelAndAddress = `${ownerLabelAndAddress} (${label})`;
  }

  p.addRow({ info: "Owner", value: ownerLabelAndAddress }, defaultValColors);

  p.printTable();
}

module.exports = async function (taskArgs, hre) {
  const masterContracts = {};

  console.log(`Using network ${hre.network.name}`);
  const config = loadConfig(hre.network.name);
  console.log(`Retrieving cauldron information...`);

  if (taskArgs.cauldron == "all") {
    for (const cauldron of config.cauldrons) {
      let cauldronConfig = getCauldron(config, cauldron.key);

      if (cauldronConfig.version >= 2) {
        const cauldronInfo = await getCauldronInformationUsingConfig(hre, cauldronConfig);
        printCauldronInformation(cauldronInfo);
        masterContracts[cauldronInfo.masterContract] = cauldronInfo.masterContractOwner;
      }
    }

    for (const [address, owner] of Object.entries(masterContracts)) {
      printMastercontractInformation(hre, hre.network.name, address, owner);
    }
    return;
  }

  const cauldron = await getCauldronInformation(hre, config, taskArgs.cauldron);
  printCauldronInformation(cauldron);
};
