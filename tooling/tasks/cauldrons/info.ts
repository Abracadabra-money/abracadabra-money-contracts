import {Table} from "console-table-printer";
import type {NetworkName, TaskArgs, TaskFunction, TaskMeta} from "../../types";
import {
    getCauldronInformation,
    getCauldronInformationUsingConfig,
    printCauldronInformation,
    type CauldronConfigEntry,
    type CauldronOwnerInfo,
    type MasterContractInfo,
} from "../utils/cauldrons";
import type {Tooling} from "../../tooling";

export const meta: TaskMeta = {
    name: "cauldron:info",
    description: "Print cauldron information and master contract information",
    options: {
        cauldron: {
            type: "string",
            description: "Cauldron name",
            required: false,
        },
        network: {
            type: "string",
            description: "Network to use",
            required: true,
        },
    },
};

const printMastercontractInformation = async (tooling: Tooling, networkName: NetworkName, info: MasterContractInfo) => {
    const p = new Table({
        columns: [
            {name: "info", alignment: "right", color: "cyan"},
            {name: "value", alignment: "left"},
        ],
    });

    const defaultValColors = {color: "green"};

    p.addRow({info: "Address", value: info.address}, defaultValColors);
    p.addRow({info: "Owner", value: tooling.getLabeledAddress(networkName, info.owner)}, defaultValColors);
    p.addRow({info: "FeeTo", value: tooling.getLabeledAddress(networkName, info.feeTo)}, defaultValColors);
    p.addRow({info: "Box", value: tooling.getLabeledAddress(networkName, (await info.box.getAddress()).toString())}, defaultValColors);

    p.printTable();
};

const printCauldronOwnerInformation = (tooling: Tooling, networkName: NetworkName, info: CauldronOwnerInfo) => {
    const p = new Table({
        columns: [
            {name: "info", alignment: "right", color: "cyan"},
            {name: "value", alignment: "left"},
        ],
    });

    const defaultValColors = {color: "green"};

    p.addRow({info: "Address", value: tooling.getLabeledAddress(networkName, info.address)}, defaultValColors);
    p.addRow({info: "Treasury", value: tooling.getLabeledAddress(networkName, info.treasury)}, defaultValColors);
    p.addRow({info: "Registry", value: tooling.getLabeledAddress(networkName, info.registry)}, defaultValColors);

    p.printTable();
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const masterContracts: Record<string, MasterContractInfo> = {};
    const cauldronOwners: Record<string, CauldronOwnerInfo> = {};

    console.log(`Using network ${tooling.network.name}`);

    const config = tooling.getNetworkConfigByName(tooling.network.name);

    if (!taskArgs.cauldron) {
        if (config.addresses?.cauldrons === undefined) {
            console.log("No cauldrons found");
            return;
        }

        const cauldronNames = Object.keys(config.addresses?.cauldrons);
        for (const cauldronName of cauldronNames) {
            console.log(`Retrieving cauldron information for ${cauldronName}...`);

            const cauldronConfigEntry = config.addresses?.cauldrons[cauldronName] as CauldronConfigEntry;
            const cauldronInfo = await getCauldronInformationUsingConfig(tooling, cauldronConfigEntry);
            await printCauldronInformation(tooling, cauldronInfo);

            masterContracts[cauldronInfo.masterContract] = {
                address: cauldronInfo.masterContract,
                box: cauldronInfo.bentoBox,
                owner: cauldronInfo.masterContractOwner,
                feeTo: cauldronInfo.feeTo,
            };

            if (cauldronInfo.cauldronOwnerInfo) {
                cauldronOwners[cauldronInfo.masterContractOwner] = cauldronInfo.cauldronOwnerInfo;
            }
        }
    } else {
        const cauldronInfo = await getCauldronInformation(tooling, taskArgs.cauldron as string);
        await printCauldronInformation(tooling, cauldronInfo);

        masterContracts[cauldronInfo.masterContract] = {
            address: cauldronInfo.masterContract,
            box: cauldronInfo.bentoBox,
            owner: cauldronInfo.masterContractOwner,
            feeTo: cauldronInfo.feeTo,
        };

        if (cauldronInfo.cauldronOwnerInfo) {
            cauldronOwners[cauldronInfo.masterContractOwner] = cauldronInfo.cauldronOwnerInfo;
        }
    }

    console.log("\nMasterContracts Information");
    for (const [, info] of Object.entries(masterContracts)) {
        await printMastercontractInformation(tooling, tooling.network.name, info);
    }

    console.log("\nCauldron Owners Information");
    for (const [, info] of Object.entries(cauldronOwners)) {
        printCauldronOwnerInformation(tooling, tooling.network.name, info);
    }
};
