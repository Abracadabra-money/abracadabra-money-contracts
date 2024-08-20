import {Table} from "console-table-printer";
import type {TaskArgs, TaskFunction, TaskMeta} from "../../types";
import {
    getCauldronInformation,
    getCauldronInformationUsingConfig,
    printCauldronInformation,
    type CauldronConfigEntry,
    type CauldronStatus,
    type MasterContractInfo,
} from "../utils/cauldrons";
import type { Tooling } from "../../tooling";

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

const printMastercontractInformation = (tooling: Tooling, networkName: string, info: MasterContractInfo) => {
    const p = new Table({
        columns: [
            {name: "info", alignment: "right", color: "cyan"},
            {name: "value", alignment: "left"},
        ],
    });

    const defaultValColors = {color: "green"};

    p.addRow({info: "Address", value: info.address}, defaultValColors);

    const labeledOwnerAddress = tooling.getLabeledAddress(networkName, info.owner);
    p.addRow({info: "Owner", value: labeledOwnerAddress}, defaultValColors);

    const labeledFeeToAddress = tooling.getLabeledAddress(networkName, info.feeTo);
    p.addRow({info: "FeeTo", value: labeledFeeToAddress}, defaultValColors);

    p.printTable();
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const masterContracts: Record<string, MasterContractInfo> = {};

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
            if (cauldronConfigEntry.version >= 2) {
                const cauldronInfo = await getCauldronInformationUsingConfig(tooling, cauldronConfigEntry);
                printCauldronInformation(tooling, cauldronInfo);

                masterContracts[cauldronInfo.masterContract] = {
                    address: cauldronInfo.masterContract,
                    owner: cauldronInfo.masterContractOwner,
                    feeTo: cauldronInfo.feeTo,
                };
            }
        }
    } else {
        const cauldronInfo = await getCauldronInformation(tooling, taskArgs.cauldron as string);
        printCauldronInformation(tooling, cauldronInfo);

        masterContracts[cauldronInfo.masterContract] = {
            address: cauldronInfo.masterContract,
            owner: cauldronInfo.masterContractOwner,
            feeTo: cauldronInfo.feeTo,
        };
    }

    console.log("\nMasterContracts Information");
    for (const [, info] of Object.entries(masterContracts)) {
        printMastercontractInformation(tooling, tooling.network.name, info);
    }
};
