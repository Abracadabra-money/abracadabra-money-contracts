import {ethers} from "ethers";
import chalk from "chalk";
import type {TaskArgs, TaskFunction, TaskMeta} from "../../types";
import type {Tooling} from "../../tooling";
import {transferAmountStringToWei} from "../utils";
import {confirm} from "@inquirer/prompts";

export const meta: TaskMeta = {
    name: "cauldron:topup",
    description: "Deposit MIM into a cauldron",
    options: {
        cauldron: {
            type: "string",
            description: "Cauldron key name (e.g. 'WETH', 'magicGLP', etc)",
            required: true,
        },
        network: {
            type: "string",
            description: "Network name",
            required: true,
        },
        amount: {
            type: "string",
            description: "Amount of MIM to deposit (in token units ex: 100eth, default is wei)",
            required: true,
            transform: transferAmountStringToWei,
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    await tooling.init();

    const amount = BigInt(taskArgs.amount as string);
    
    // Get cauldron using getCauldronByLabel
    const cauldron = tooling.getCauldronByLabel(tooling.network.name, taskArgs.cauldron as string);
    if (!cauldron) {
        console.error(chalk.red(`Cauldron ${taskArgs.cauldron} not found`));
        process.exit(1);
    }

    // Add confirmation prompt
    const proceed = await confirm({
        message: `Are you sure you want to deposit ${ethers.formatEther(amount)} MIM to ${cauldron.key} Cauldron?`,
        default: false
    });

    if (!proceed) {
        process.exit(0);
    }

    // Get signer
    const deployer = await tooling.getOrLoadDeployer();
    const deployerAddress = await deployer.getAddress();

    // Get contracts
    const cauldronContract = await tooling.getContractAt("ICauldronV2", cauldron.value);
    const degenBox = await tooling.getContractAt("IBentoBoxV1", await cauldronContract.bentoBox());
    const mim = await tooling.getContractAt("IERC20", await cauldronContract.magicInternetMoney());

    // Check and set approval if needed
    const allowance = await mim.connect(deployer).allowance(deployerAddress, await degenBox.getAddress());
    if (allowance < amount) {
        console.log(chalk.yellow("Approving MIM..."));
        const tx = await mim.connect(deployer).approve(await degenBox.getAddress(), ethers.MaxUint256);
        await tx.wait();
        console.log(chalk.green("MIM approved"));
    }

    // Deposit MIM
    console.log(chalk.yellow(`Depositing ${ethers.formatEther(amount)} MIM to ${cauldron.key} Cauldron...`));
    const tx = await degenBox.connect(deployer).deposit(
        await mim.getAddress(),    // token
        deployerAddress,           // from
        cauldron.value,           // to (cauldron address)
        amount,                    // amount
        0                         // share (0 to calculate from amount)
    );

    const receipt = await tx.wait();
    console.log(chalk.green(`Successfully deposited ${ethers.formatEther(amount)} MIM to ${cauldron.key}`));
    console.log(chalk.blue(`Transaction hash: ${receipt.hash}`));
};
