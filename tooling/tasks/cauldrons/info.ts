import { Table } from 'console-table-printer';
import type { TaskArgs, TaskFunction, TaskMeta, Tooling } from '../../types';
import { getCauldronInformation, getCauldronInformationUsingConfig, printCauldronInformation, type CauldronConfigEntry } from '../utils/cauldrons';

export const meta: TaskMeta = {
    name: 'cauldron:info',
    description: 'Print cauldron information and master contract information',
    options: {
        cauldron: {
            type: 'string',
            description: 'Cauldron name or "all"',
            required: true,
        },
    },
};

const printMastercontractInformation = (tooling: Tooling, networkName: string, address: `0x${string}`, owner: string | `0x${string}`) => {
    const p = new Table({
        columns: [
            { name: 'info', alignment: 'right', color: 'cyan' },
            { name: 'value', alignment: 'left' },
        ],
    });

    const defaultValColors = { color: 'green' };

    p.addRow({ info: 'Address', value: address }, defaultValColors);

    let ownerLabelAndAddress = owner;
    const label = tooling.getLabelByAddress(networkName, owner as `0x${string}`);
    if (label) {
        ownerLabelAndAddress = `${ownerLabelAndAddress} (${label})`;
    }

    p.addRow({ info: 'Owner', value: ownerLabelAndAddress }, defaultValColors);
    p.printTable();
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const masterContracts: Record<string, string> = {};

    console.log(`Using network ${tooling.network.name}`);

    const config = tooling.getNetworkConfigByName(tooling.network.name);

    if (taskArgs.cauldron === 'all') {
        if(config.addresses?.cauldrons === undefined) {
            console.log('No cauldrons found');
            return;
        }
        
        const cauldronNames = Object.keys(config.addresses?.cauldrons);
        for (const cauldronName of cauldronNames) {
            console.log(`Retrieving cauldron information for ${cauldronName}...`);
            
            const cauldronConfigEntry = config.addresses?.cauldrons[cauldronName] as CauldronConfigEntry;
            if (cauldronConfigEntry.version >= 2) {
                const cauldronInfo = await getCauldronInformationUsingConfig(tooling, cauldronConfigEntry);
                printCauldronInformation(tooling, cauldronInfo);
                masterContracts[cauldronInfo.masterContract] = cauldronInfo.masterContractOwner;
            }
        }

        for (const [address, owner] of Object.entries(masterContracts)) {
            printMastercontractInformation(tooling, tooling.network.name, address as `0x${string}`, owner);
        }

        return;
    }

    const cauldron = await getCauldronInformation(tooling, taskArgs.cauldron as string);
    printCauldronInformation(tooling, cauldron);
};