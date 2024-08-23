import { Table } from "console-table-printer";
import { type TaskArgs, type TaskFunction, type TaskMeta } from "../../types";
import type { Tooling } from "../../tooling";
import { uniqueColorFromAddress } from "../utils";

export const meta: TaskMeta = {
    name: "core/address",
    description: "Get network addresses or a specific address",
    options: {
        network: {
            type: "string",
            description: "Network to use",
            required: false,
        },
    },
    positionals: {
        name: "name",
        description: "Name of the address",
        required: false,
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const networks = taskArgs.network ? [taskArgs.network] : tooling.getAllNetworks();
    const addresses: { name: string; network: string; address: `0x${string}` }[] = [];

    const p = new Table({
        columns: [
            { name: "network", alignment: "right", color: "green" },
            { name: "name", alignment: "right", color: "green" },
            { name: "address", alignment: "left" },
        ],
    });


    for (const network of networks) {
        if (taskArgs.name) {
            const address = tooling.getAddressByLabel(network as string, taskArgs.name as string);

            if (!address) {
                console.log(`Address not found for ${taskArgs.name}, network: ${network}`);
                process.exit(1);
            }

            addresses.push({
                network: network as string,
                name: taskArgs.name as string,
                address: `${address} ${tooling.getFormatedAddressLabelScopeAnnotation(network as string, taskArgs.name as string)}`,
            });
        } else {
            const config = tooling.getNetworkConfigByName(network as string);

            if (!config.addresses) {
                console.log(`No addresses found for network ${network}`);
                process.exit(1);
            }

            for (const [name, entry] of Object.entries(config.addresses.addresses)) {
                addresses.push({
                    network: network as string,
                    name,
                    address: `${entry.value} ${tooling.getFormatedAddressLabelScopeAnnotation(network as string, name)}`,
                });
            }
        }
    }

    for (const { network, name, address } of addresses) {
        const coloredAddress = uniqueColorFromAddress(address);
        p.addRow({
            network,
            name,
            address: coloredAddress,
        });
    }

    p.printTable();
};
