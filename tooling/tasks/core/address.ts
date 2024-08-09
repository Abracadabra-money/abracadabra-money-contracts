import {Table} from "console-table-printer";
import type {TaskArgs, TaskFunction, TaskMeta, Tooling} from "../../types";
import chalk, { backgroundColorNames } from "chalk";
import { ethers } from "ethers";

export const meta: TaskMeta = {
    name: "core:address",
    description: "Get network addresses or a specific address",
    options: {
        network: {
            type: "string",
            description: "Network to use",
            required: true,
        },
    },
    positionals: {
        name: "name",
        description: "Name of the address",
        required: false,
    },
};

const formatAddress = (tooling: Tooling, label: string, address: string): string => {
    address = ethers.utils.getAddress(address);

    const defaultAddress = tooling.getDefaultAddressByLabel(label);
    if (defaultAddress) {
        if (address === defaultAddress) {
            return `${address} ${chalk.gray(" (default)")}`;
        }

        return `${address} ${chalk.blue(" (overridden)")}`;
    }

    return `${address} ${chalk.yellow(" (specific)")}`;
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const addresses: {name: string; address: string}[] = [];

    if (taskArgs.name) {
        const address = tooling.getAddressByLabel(taskArgs.network as string, taskArgs.name as string);

        if (!address) {
            console.log(`Address not found for ${taskArgs.name}, network: ${taskArgs.network}`);
            process.exit(1);
        }

        console.log(tooling.getDefaultAddressByLabel(taskArgs.name as string));
        addresses.push({
            name: taskArgs.name as string,
            address: formatAddress(tooling, taskArgs.name as string, address),
        });
    } else {
        const config = tooling.getNetworkConfigByName(taskArgs.network as string);

        if (!config.addresses) {
            console.log(`No addresses found for network ${taskArgs.network}`);
            process.exit(1);
        }

        for (const [name, entry] of Object.entries(config.addresses.addresses)) {
            addresses.push({name, address: formatAddress(tooling, name, entry.value)});
        }
    }

    const p = new Table({
        columns: [
            {name: "name", alignment: "right", color: "cyan"},
            {name: "address", alignment: "left"},
        ],
    });

    const defaultValColors = {color: "green"};

    for (const {name, address} of addresses) {
        p.addRow({name, address}, defaultValColors);
    }

    p.printTable();
};
