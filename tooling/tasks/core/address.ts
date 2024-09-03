import {Table} from "console-table-printer";
import {type TaskArgs, type TaskFunction, type TaskMeta} from "../../types";
import type {Tooling} from "../../tooling";
import {uniqueColorFromAddress} from "../utils";

export const meta: TaskMeta = {
    name: "core/address",
    description: "Get network addresses or a specific address",
    options: {
        network: {
            type: "string",
            description: "Network to use",
            required: false,
        },
        strict: {
            type: "boolean",
            description: "Strict match",
            required: false,
            default: false,
        },
        caseSensitive: {
            type: "boolean",
            description: "Case sensitive",
            required: false,
            default: false,
        },
    },
    positionals: {
        name: "match",
        description: "Address names to search for",
        required: false,
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const networks = taskArgs.network ? [taskArgs.network] : tooling.getAllNetworks();
    const addresses: {name: string; network: string; address: `0x${string}`}[] = [];

    const p = new Table({
        columns: [
            {name: "network", alignment: "right", color: "green"},
            {name: "name", alignment: "right", color: "green"},
            {name: "address", alignment: "left"},
        ],
    });

    const matches = (taskArgs.match as string[]) ?? [];
    const addedAddresses = new Set<string>();

    for (const network of networks) {
        const config = tooling.getNetworkConfigByName(network as string);

        let filteredAddresses = matches.length == 0 ? Object.entries(config.addresses.addresses) : [];

        for (const match of matches) {
            const value = taskArgs.caseSensitive ? match : match.toLowerCase();
            filteredAddresses = [
                ...filteredAddresses,
                ...Object.entries(config.addresses.addresses).filter(([name]) => {
                    name = taskArgs.caseSensitive ? name : name.toLowerCase();
                    return taskArgs.strict ? name == value : name.includes(value);
                }),
            ];
        }

        for (const [name, entry] of filteredAddresses) {
            const addressKey = `${network}-${name}`;

            if (!addedAddresses.has(addressKey)) {
                addresses.push({
                    network: network as string,
                    name,
                    address: `${entry.value} ${tooling.getFormatedAddressLabelScopeAnnotation(network as string, name)}`,
                });
                addedAddresses.add(addressKey);
            }
        }
    }

    for (const {network, name, address} of addresses) {
        const coloredAddress = uniqueColorFromAddress(address);
        p.addRow({
            network,
            name,
            address: coloredAddress,
        });
    }

    p.printTable();
};
