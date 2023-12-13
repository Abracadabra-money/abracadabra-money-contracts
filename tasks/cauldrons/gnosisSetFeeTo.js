const fs = require('fs');
const { calculateChecksum } = require("../utils/gnosis");

module.exports = async function (taskArgs, hre) {
    const { getContractAt, getChainIdByNetworkName, changeNetwork } = hre;
    const foundry = hre.userConfig.foundry;

    const networks = ["mainnet", "arbitrum", "avalanche", "fantom"];

    // using create3, same address accross chains
    const withdrawer = "0x2C9f65BD1a501CB406584F5532cE57c28829B131";

    const cauldronOwners = [
        "0x30B9dE623C209A42BA8d5ca76384eAD740be9529",
        "0xaF2fBB9CB80EdFb7d3f2d170a65AE3bFa42d0B86"
    ];

    const defaultBatch = Object.freeze({
        version: "1.0",
        chainId: "",
        createdAt: 0,
        meta: {},
        transactions: [

        ]
    });

    const defaultSetTo = Object.freeze({
        to: "",
        value: "0",
        data: null,
        contractMethod: {
            inputs: [
                {
                    internalType: "address",
                    name: "newFeeTo",
                    type: "address"
                }
            ],
            name: "setFeeTo",
            payable: false
        },
        contractInputsValues: {
            newFeeTo: ""
        }

    });

    const cauldronOwnerSetTo = Object.freeze({
        to: "",
        value: "0",
        data: null,
        contractMethod: {
            inputs: [
                {
                    internalType: "contract ICauldronV2",
                    name: "cauldron",
                    type: "address"
                },
                {
                    internalType: "address",
                    name: "newFeeTo",
                    type: "address"
                }
            ],
            name: "setFeeTo",
            payable: false
        },
        contractInputsValues: {
            cauldron: "",
            newFeeTo: ""
        }
    });


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
        const filename = `${hre.config.paths.root}/${foundry.out}/${network}-setFeeTo-batch.json`;
        fs.writeFileSync(filename, JSON.stringify(batch, null, 4), 'utf8');
        console.log(`Transaction batch saved to ${filename}`);
    }
}