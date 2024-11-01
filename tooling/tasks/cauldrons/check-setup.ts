import chalk from "chalk";
import type {NetworkName, TaskArgs, TaskFunction, TaskMeta, CauldronAddressEntry, AddressSections} from "../../types";
import type {Tooling} from "../../tooling";
import {getCauldronInformation} from "../utils/cauldrons";

const CHECK_MARK = "✅";
const ERROR_MARK = "❌";

export const meta: TaskMeta = {
    name: "cauldron:check-setup",
    description: "Verify cauldrons setup against configuration",
    options: {
        network: {
            type: "string",
            description: "Network to check",
            required: true,
        },
        cauldron: {
            type: "string",
            description: "Cauldron to check",
            required: false,
        },
    },
};

async function checkCauldronRegistry(tooling: Tooling, cauldron: CauldronAddressEntry, version: number): Promise<void> {
    const registryAddress = tooling.getAddressByLabel(tooling.network.name, "cauldronRegistry") as `0x${string}`;
    const registry = await tooling.getContractAt("CauldronRegistry", registryAddress);

    if (!(await registry.registered(cauldron.value))) {
        console.log(`${ERROR_MARK} Registry: Cauldron ${cauldron.name} not registered`);
        console.log(chalk.gray(`For operators, run this command to register the cauldron.`));
        console.log(
            chalk.gray(
                `cast send --rpc-url ${tooling.network.config.url} ${registryAddress} --account deployer "add((address,uint8,bool)[])" "[(${cauldron.value},${version},${cauldron.status === "deprecated"})]"`
            )
        );
        process.exit(1);
    }

    const info = await registry["get(address)"](cauldron.value);
    const isVersionMatch = info.version.toString() === version.toString();
    const isDeprecatedMatch = info.deprecated === (cauldron.status === "deprecated");

    if (!isVersionMatch) {
        console.log(`${ERROR_MARK} Registry: Version mismatch - Expected: v${version}, Got: v${info.version}`);
        process.exit(1);
    }

    if (!isDeprecatedMatch) {
        console.log(
            `${ERROR_MARK} Registry: Deprecated mismatch - Expected: ${cauldron.status}, Got: ${info.deprecated ? "true" : "false"}`
        );
        process.exit(1);
    }

    console.log(`${CHECK_MARK} Registry: Registered correctly with version ${version}`);
}

async function checkCauldronOwner(tooling: Tooling, cauldron: CauldronAddressEntry): Promise<void> {
    const expectedOwner1 = tooling.getAddressByLabel(tooling.network.name, "cauldronOwner") as `0x${string}`;
    const expectedOwner2 = tooling.getAddressByLabel(tooling.network.name, "cauldronOwner.old") as `0x${string}`;
    const expectedOwners = [expectedOwner1, expectedOwner2];

    const cauldronInfo = await getCauldronInformation(tooling, cauldron.name);

    const matchingOwner = expectedOwners.find((owner) => owner.toLowerCase() === cauldronInfo.masterContractOwner.toLowerCase());
    const formattedExpectedOwner = expectedOwners.map((owner) => tooling.getLabeledAddress(tooling.network.name, owner)).join(" or ");
    const formattedActualOwner = tooling.getLabeledAddress(tooling.network.name, cauldronInfo.masterContractOwner);

    if (!matchingOwner) {
        console.log(
            `${ERROR_MARK} Owner: Wrong owner for masterContract ${cauldronInfo.masterContract} - Expected: ${formattedExpectedOwner}, Got: ${formattedActualOwner}`
        );
        process.exit(1);
    }

    console.log(`${CHECK_MARK} Owner: Correct owner: ${formattedActualOwner}`);
}

async function checkCauldronFeeWithdrawer(tooling: Tooling, cauldron: CauldronAddressEntry): Promise<void> {
    const feeWithdrawerAddress = tooling.getAddressByLabel(tooling.network.name, "cauldronFeeWithdrawer") as `0x${string}`;
    const cauldronInfo = await getCauldronInformation(tooling, cauldron.name);
    const masterContract = await tooling.getContractAt("ICauldronV1", cauldronInfo.masterContract);
    const feeTo = await masterContract.feeTo();

    const formattedExpectedFeeTo = tooling.getLabeledAddress(tooling.network.name, feeWithdrawerAddress);
    const formattedActualFeeTo = tooling.getLabeledAddress(tooling.network.name, feeTo);

    if (feeTo.toLowerCase() !== feeWithdrawerAddress.toLowerCase()) {
        console.log(
            `${ERROR_MARK} Fee Withdrawer: Wrong feeTo address for masterContract ${masterContract.address} - Expected: ${formattedExpectedFeeTo}, Got: ${formattedActualFeeTo}`
        );
        process.exit(1);
    }

    console.log(`${CHECK_MARK} Fee Withdrawer: Correct feeTo`);
}

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    await tooling.init();

    const networkName = taskArgs.network as NetworkName;
    const networkConfig = tooling.getNetworkConfigByName(networkName);

    let cauldrons: AddressSections[string] | undefined;
    if (taskArgs.cauldron) {
        const cauldron = tooling.getCauldronByLabel(networkName, taskArgs.cauldron as string);
        if (!cauldron) {
            console.error(chalk.red(`Cauldron ${taskArgs.cauldron} not found in config`));
            process.exit(1);
        }
        cauldrons = {[taskArgs.cauldron as string]: cauldron};
    } else {
        cauldrons = networkConfig.addresses?.cauldrons;
    }

    if (!cauldrons) {
        console.error(chalk.red("No cauldrons found in config"));
        process.exit(1);
    }

    for (const cauldronKey of Object.keys(cauldrons)) {
        const cauldron = tooling.getCauldronByLabel(networkName, cauldronKey);
        if (!cauldron) {
            console.error(chalk.red(`Cauldron ${cauldronKey} not found in config`));
            continue;
        }

        console.log(chalk.cyan(`\nChecking cauldron: ${cauldronKey}`));
        console.log(chalk.gray(`Address: ${tooling.getLabeledAddress(tooling.network.name, cauldron.value)}`));

        await checkCauldronRegistry(tooling, cauldron, cauldron.version);
        await checkCauldronOwner(tooling, cauldron);
        await checkCauldronFeeWithdrawer(tooling, cauldron);
    }
};
