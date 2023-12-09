const fs = require("fs");
const { BigNumber } = require("ethers");
const { calculateChecksum } = require("../utils/gnosis");
const { getAddress, getCauldron, loadConfig, WAD, printCauldronInformation, getCauldronInformation } = require("../utils/toolkit");
const inquirer = require('inquirer');

module.exports = async function (taskArgs, hre) {
  const { getContractAt, getChainIdByNetworkName, changeNetwork } = hre;
  const foundry = hre.userConfig.foundry;

  taskArgs.cauldrons = taskArgs.cauldrons.split(",").map((c) => c.trim());
  taskArgs.amounts = taskArgs.amounts.split(",").map((a) => a.trim());

  if (taskArgs.cauldrons.length !== taskArgs.amounts.length) {
    console.log("cauldrons and amounts must be the same length");
    process.exit();
  }

  const chainId = hre.network.config.chainId;
  const network = hre.network.name;
  console.log(`Using network ${network}`);

  const config = loadConfig(network);
  const mim = getAddress(config, "mim");
  const safe = getAddress(config, "safe.main");

  const defaultApproveTx = Object.freeze({
    to: mim,
    value: "0",
    data: null,
    contractMethod: {
      inputs: [
        { name: "spender", type: "address", internalType: "address" },
        { name: "value", type: "uint256", internalType: "uint256" },
      ],
      name: "approve",
      payable: false,
    },
    contractInputsValues: {
      spender: "",
      value: "",
    },
  });

  const defaultDepositTx = Object.freeze({
    to: "<degenbox address here>",
    value: "0",
    data: null,
    contractMethod: {
      inputs: [
        {
          name: "token_",
          type: "address",
          internalType: "contract IERC20",
        },
        { name: "from", type: "address", internalType: "address" },
        { name: "to", type: "address", internalType: "address" },
        { name: "amount", type: "uint256", internalType: "uint256" },
        { name: "share", type: "uint256", internalType: "uint256" },
      ],
      name: "deposit",
      payable: true,
    },
    contractInputsValues: {
      token_: mim,
      from: safe,
      to: "<cauldron address here>",
      amount: "<amount here>",
      share: "0",
    },
  });

  const batch = {
    version: "1.0",
    chainId: chainId.toString(),
    createdAt: new Date().getTime(),
    meta: {},
    transactions: [],
  };

  console.log(`Loading cauldron information..`);

  // retrieve the cauldron config for all taskArgs.cauldrons
  const cauldrons = await Promise.all(
    taskArgs.cauldrons.map(async (cauldron) => {
      const item = getCauldron(config, cauldron);
      const info = await getCauldronInformation(hre, config, cauldron);
      const contract = await hre.getContractAt("ICauldronV2", item.value);

      item.box = await contract.bentoBox();
      item.amount = taskArgs.amounts.shift();
      item.info = info;
      return item;
    })
  );

  // group cauldron by box
  const cauldronsByBox = cauldrons.reduce((acc, cauldron) => {
    if (!acc[cauldron.box]) {
      acc[cauldron.box] = [];
    }
    acc[cauldron.box].push(cauldron);
    return acc;
  }, {});

  for (const box of Object.keys(cauldronsByBox)) {
    const cauldrons = cauldronsByBox[box];
    const totalAmount = cauldrons.reduce((acc, c) => acc.add(BigNumber.from(c.amount).mul(WAD)), BigNumber.from(0))

    // Approve MIM to BentoBox
    const approvalTx = JSON.parse(JSON.stringify(defaultApproveTx));
    approvalTx.contractInputsValues.spender = box;
    approvalTx.contractInputsValues.value = totalAmount.toString();
    batch.transactions.push(approvalTx);
  }

  for (const cauldron of cauldrons) {
    // Deposit
    const depositTx = JSON.parse(JSON.stringify(defaultDepositTx));
    depositTx.to = cauldron.box;
    depositTx.contractInputsValues.to = cauldron.value;
    depositTx.contractInputsValues.amount = BigNumber.from(cauldron.amount).mul(WAD).toString();
    batch.transactions.push(depositTx);

    printCauldronInformation(cauldron.info, [
      [{
        info: "Top Up Amount",
        value: `${parseFloat(BigNumber.from(cauldron.amount).toString()).toLocaleString('us')} MIM`,
      }, {
        color: "red"
      }]
    ]);

    const answers = await inquirer.prompt([
      {
        name: 'confirm',
        type: 'confirm',
        default: false,
        message: `Write transaction?`,
      }
    ]);

    if (answers.confirm === false) {
      console.log("Aborting...");
      process.exit(0);
    }
  }

  batch.meta.checksum = calculateChecksum(hre.ethers, batch);
  content = JSON.stringify(batch, null, 4);

  const filename = `${hre.config.paths.root}/${foundry.out}/${network}-topup.json`;
  fs.writeFileSync(filename, content, 'utf8');
  console.log(`Transaction batch saved to ${filename}`);
}
