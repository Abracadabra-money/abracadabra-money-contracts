/*
CODE TO PORT HERE FROM PYTHON:

def topUpCauldrons(cauldronIdentifier, amounts, nonce=None):
    safe = ApeSafe('0x5f0DeE98360d8200b20812e174d139A1a633EDd2')

    mim = safe.contract('0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3')
    bentoBox = safe.contract('0xF5BCE5077908a1b7370B9ae04AdC565EBd643966')
    degenBox = safe.contract('0xd96f48665a1410C0cd669A88898ecA36B9Fc2cce')

    for i in range(len(cauldronIdentifier)):

        amount = Wei(amounts[i]*1e6*1e18)

        cauldron = safe.contract(mainnet[cauldronIdentifier[i]])

        cauldronBentoBox = safe.contract(cauldron.bentoBox())

        if(cauldronBentoBox.address == bentoBox.address):
            print("Cauldron " + cauldron.address + " " + cauldronIdentifier[i] + " is using BentoBox")
        elif(cauldronBentoBox.address == degenBox.address):
            print("Cauldron " + cauldron.address + " " + cauldronIdentifier[i] + " is using DegenBox")
        else:
            raise ValueError("The BentoBox used is unknown.")
        
        if not (cauldronBentoBox.masterContractOf(cauldron) in approvedMasterContractMainnet):
            raise ValueError("The MasterContract is not known.")
    
        if not (cauldronBentoBox.whitelistedMasterContracts(cauldronBentoBox.masterContractOf(cauldron))):
            raise ValueError("The MasterContract is not whitelisted.")
        
        print("Top Up of " + str(amount / 1e18 / 1e6) + " M MIM.")
        
        getCauldronInformation(cauldron)

        cauldron.updateExchangeRate()

        if cauldronBentoBox.toAmount(mim, cauldronBentoBox.balanceOf(mim, safe), False) >= amount:
            cauldronBentoBox.transfer(mim, safe, cauldron, cauldronBentoBox.toShare(mim, amount, True))
        else:
            mim.mint(cauldronBentoBox.address, amount)
            cauldronBentoBox.deposit(mim, cauldronBentoBox, cauldron, amount, 0)

    safe_tx = safe.multisend_from_receipts(None, nonce)
    safe.preview(safe_tx, call_trace=False)
    safe.post_transaction(safe_tx)

def getCauldronInformation(cauldron, withAccrue=False):
    if isinstance(cauldron, str):
        cauldron = Contract(cauldron)
    if withAccrue:
        cauldron.accrue()
    accrueInfo = cauldron.accrueInfo()
    interest = str(0) if len(accrueInfo) != 3 else str(round(cauldron.accrueInfo()[2] * 365.25*3600*24 / 1e16, 2))
    liq_multiplier = str(0) if interest == str(0) else str(cauldron.LIQUIDATION_MULTIPLIER() / 1e3 - 100)
    collateralization =  str(0) if interest == str(0) else str(cauldron.COLLATERIZATION_RATE() / 1e3)
    opening = str(0) if interest == str(0) else cauldron.BORROW_OPENING_FEE() / 1e3
    borrow = cauldron.totalBorrow()[0] / 1e18
    bentoBox = Contract(cauldron.bentoBox())
    mim = Contract(cauldron.magicInternetMoney())
    collateral = Contract(cauldron.collateral())
    collateralAmount = bentoBox.toAmount(collateral, cauldron.totalCollateralShare(), False) / 1e18
    oracle = Contract(cauldron.oracle())
    oracleData = cauldron.oracleData()
    peekSpot = oracle.peekSpot(oracleData)
    decimals = 10**collateral.decimals()
    spotPrice = decimals / peekSpot
    exchangeRate = cauldron.exchangeRate()
    currentPrice = decimals / exchangeRate if exchangeRate > 0 else 0
    peekPrice = oracle.peek(oracleData)[1]
    futurePrice = decimals / peekPrice
    collateralValue = collateralAmount * spotPrice
    ltv = borrow / collateralValue if collateralValue > 0 else 0
    mimAmount = bentoBox.toAmount(mim, bentoBox.balanceOf(mim, cauldron), False)
    # relies on 18 decimal collaterals

    print("Cauldron Information: ")
    print("Interest: " + interest + " %")
    print("Liquidation Multiplier: " + liq_multiplier + " %")
    print("Available to be borrowed: " + str("{:,.2f}".format(mimAmount / 1e6 / 1e18)) + " M MIM")
    print("Collateralization: " + collateralization + " %")
    print("Opening fee: " + str(opening) + " %")
    print("Total Borrowed: " + str("${:,.2f}".format(borrow)) + " MIM")
    print("Collateral: " + Contract(cauldron.collateral()).name() + " Amount: " + str("{:,.2f}".format(collateralAmount)) + " Value: " + str("${:,.2f}".format(collateralValue)))
    print("LTV: " +  str("{:,.2f}".format(ltv * 100)) + " %")
    print("Collateral: Price: Spot: " + str("${:,.4f}".format(spotPrice)) + " Current: " + str("${:,.4f}".format(currentPrice)) + " Future: " + str("${:,.4f}".format(futurePrice)))
    if(not confirm()):
        raise ValueError("User denied confirmation.")
    return spotPrice
*/
const fs = require("fs");
const { calculateChecksum } = require("../utils/gnosis");
const { task } = require("hardhat/config");

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

  const config = require(`../../config/${network}.json`);

  const safe = config.addresses.find((a) => a.key === "safe.main").value;
  if (!safe) {
    console.log(`No safe address 'safe.main' found for ${network}`);
    process.exit(1);
  }

  const mim = config.addresses.find((a) => a.key === "mim").value;
  if (!mim) {
    console.log(`No mim address found for ${network}`);
    process.exit(1);
  }

  const printAvailableCauldrons = () => {
    console.log("Available cauldrons:");
    for (const cauldron of config.cauldrons) {
      console.log(`- ${cauldron.key}`);
    }
  };

  // retrieve the cauldron config for all taskArgs.cauldrons
  const cauldrons = await Promise.all(
    taskArgs.cauldrons.map(async (cauldron) => {
      const item = config.cauldrons.find((c) => c.key === cauldron);
      if (!item) {
        console.log(`Cauldron ${cauldron} doesn't exist `);
        printAvailableCauldrons();
        process.exit(1);
      }

      const contract = await hre.ethers.getContractAt(
        ["function bentoBox() view returns (address)"],
        item.value
      );

      item.box = await contract.bentoBox();
      item.amount = taskArgs.amounts.shift();

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
    to: "0x7C8FeF8eA9b1fE46A7689bfb8149341C90431D38",
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
      to: "<degenbox address here>",
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

  for(const [key, cauldrons] of cauldronsByBox) {
    const approvalTx = JSON.parse(JSON.stringify(defaultApproveTx));
    approvalTx.contractInputsValues.spender = cauldrons.box;
    approvalTx.contractInputsValues.value = cauldrons.amount;

    batch.transactions.push(defaultApproveTx);
  }

  /*
    for (const network of networks) {
        console.log(`[${network}] Generating tx batch...`);

        const chainId = getChainIdByNetworkName(network);
        await changeNetwork(network);
        const withdrawerContract = await getContractAt("CauldronFeeWithdrawer", withdrawer);

        const cauldronCount = await withdrawerContract.cauldronInfosCount();

        const masterContracts = [];
        for (let i = 0; i < cauldronCount; i++) {
            const cauldronInfo = await withdrawerContract.cauldronInfos(i);
            const cauldron = cauldronInfo.cauldron;

            const cauldronContract = await getContractAt("ICauldronV2", cauldron);
            const masterContract = await cauldronContract.masterContract();
            masterContracts.push(masterContract);
        }

        // remove duplicates
        const uniqueMasterContracts = [...new Set(masterContracts)];

        const batch = JSON.parse(JSON.stringify(defaultBatch));
        batch.chainId = chainId.toString();

        for (const masterContract of uniqueMasterContracts) {
            const cauldronMastercontract = await getContractAt("ICauldronV2", masterContract);
            if (await cauldronMastercontract.feeTo() != withdrawer) {

                const ownableMastercontractCauldron = (await getContractAt("BoringOwnable", cauldronMastercontract.address));
                const owner = (await ownableMastercontractCauldron.owner()).toString();

                if (cauldronOwners.includes(owner)) {
                    const tx = JSON.parse(JSON.stringify(cauldronOwnerSetTo));
                    tx.to = owner;
                    tx.contractInputsValues.cauldron = cauldronMastercontract.address.toString();
                    tx.contractInputsValues.newFeeTo = withdrawer.toString();
                    batch.transactions.push(tx);
                } else {
                    const tx = JSON.parse(JSON.stringify(defaultSetTo));
                    tx.to = cauldronMastercontract.address;
                    tx.contractInputsValues.newFeeTo = withdrawer.toString();
                    batch.transactions.push(tx);
                }
                continue;
            }
        }

        batch.meta.checksum = calculateChecksum(hre.ethers, batch);
        content = JSON.stringify(batch, null, 4);
        fs.writeFileSync(`${hre.config.paths.root}/${foundry.out}/${network}-setFeeTo-batch.json`, content, 'utf8');
    }*/
};
