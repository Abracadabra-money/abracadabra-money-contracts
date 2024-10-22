import fs from 'fs';
import type { NetworkName, TaskArgs, TaskFunction, TaskMeta } from '../../types';
import { calculateChecksum } from '../utils/gnosis';
import type { Tooling } from '../../tooling';

export const meta: TaskMeta = {
    name: 'cauldron:gnosis-set-feeto',
    description: 'Generate transaction batches for setting fee recipients across multiple networks',
    options: {},
};

export const task: TaskFunction = async (_: TaskArgs, tooling: Tooling) => {
    const foundry = tooling.config.foundry;

    const networks = ["mainnet", "arbitrum", "avalanche", "fantom"] as NetworkName[];

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
        transactions: [],
    });

    const defaultSetTo = Object.freeze({
        to: "",
        value: "0",
        data: null,
        contractMethod: {
            inputs: [
                { internalType: "address", name: "newFeeTo", type: "address" }
            ],
            name: "setFeeTo",
            payable: false,
        },
        contractInputsValues: { newFeeTo: "" },
    });

    const cauldronOwnerSetTo = Object.freeze({
        to: "",
        value: "0",
        data: null,
        contractMethod: {
            inputs: [
                { internalType: "contract ICauldronV2", name: "cauldron", type: "address" },
                { internalType: "address", name: "newFeeTo", type: "address" }
            ],
            name: "setFeeTo",
            payable: false,
        },
        contractInputsValues: { cauldron: "", newFeeTo: "" },
    });

    for (const network of networks) {
        console.log(`[${network}] Generating tx batch...`);

        const chainId = tooling.getChainIdByName(network);
        await tooling.changeNetwork(network);
        const withdrawerContract = await tooling.getContractAt("CauldronFeeWithdrawer", withdrawer);

        const cauldronCount = await withdrawerContract.cauldronInfosCount();

        const masterContracts: string[] = [];
        for (let i = 0; i < cauldronCount; i++) {
            const cauldronInfo = await withdrawerContract.cauldronInfos(i);
            const cauldron = cauldronInfo.cauldron;

            const cauldronContract = await tooling.getContractAt("ICauldronV2", cauldron);
            const masterContract = await cauldronContract.masterContract();
            masterContracts.push(masterContract);
        }

        const uniqueMasterContracts = [...new Set(masterContracts)];

        const batch = JSON.parse(JSON.stringify(defaultBatch));
        batch.chainId = chainId.toString();

        for (const masterContract of uniqueMasterContracts) {
            const cauldronMastercontract = await tooling.getContractAt("ICauldronV2", masterContract as `0x${string}`);
            if (await cauldronMastercontract.feeTo() !== withdrawer) {
                const ownableMastercontractCauldron = await tooling.getContractAt("BoringOwnable", await cauldronMastercontract.getAddress() as `0x${string}`);
                const owner = (await ownableMastercontractCauldron.owner()).toString();

                if (cauldronOwners.includes(owner)) {
                    const tx = JSON.parse(JSON.stringify(cauldronOwnerSetTo));
                    tx.to = owner;
                    tx.contractInputsValues.cauldron = await cauldronMastercontract.getAddress();
                    tx.contractInputsValues.newFeeTo = withdrawer.toString();
                    batch.transactions.push(tx);
                } else {
                    const tx = JSON.parse(JSON.stringify(defaultSetTo));
                    tx.to = await cauldronMastercontract.getAddress();
                    tx.contractInputsValues.newFeeTo = withdrawer.toString();
                    batch.transactions.push(tx);
                }
            }
        }

        batch.meta.checksum = calculateChecksum(batch);
        const filename = `${tooling.config.projectRoot}/${foundry.out}/${network}-setFeeTo-batch.json`;
        fs.writeFileSync(filename, JSON.stringify(batch, null, 4), 'utf8');
        console.log(`Transaction batch saved to ${filename}`);
    }
};
