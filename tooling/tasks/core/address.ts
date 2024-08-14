import {Table} from "console-table-printer";
import {type TaskArgs, type TaskFunction, type TaskMeta, type Tooling} from "../../types";

export const meta: TaskMeta = {
    name: "core/address",
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
            address: `${address} ${tooling.getFormatedAddressLabelScopeAnnotation(taskArgs.network as string, taskArgs.name as string)}`,
        });
    } else {
        const config = tooling.getNetworkConfigByName(taskArgs.network as string);

        if (!config.addresses) {
            console.log(`No addresses found for network ${taskArgs.network}`);
            process.exit(1);
        }

        for (const [name, entry] of Object.entries(config.addresses.addresses)) {
            addresses.push({
                name,
                address: `${entry.value} ${tooling.getFormatedAddressLabelScopeAnnotation(taskArgs.network as string, name)}`,
            });
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
