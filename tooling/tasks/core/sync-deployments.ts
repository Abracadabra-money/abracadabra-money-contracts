import fs from "fs";
import path from "path";
import chalk from "chalk";
import type {DeploymentArtifact, TaskArgs, TaskFunction, TaskMeta, Tooling} from "../../types";
import {ethers} from "ethers";

export const meta: TaskMeta = {
    name: "core:sync-deployments",
    description: "Read broadcast files and output deployment files",
    options: {},
};

interface DeploymentObject {
    name: string;
    address: string;
    bytecode: string;
    args_data: string;
    tx_hash: string;
    args: string[] | null;
    data: string;
    contract_name: string | null;
    artifact_path: string;
    artifact_full_path: string;
    chain_id: string;
}

interface FileContent {
    transactions: TransactionResult[];
    returns: any;
}

interface TransactionResult {
    hash: string;
    transactionType: string;
    contractName: string | null;
    contractAddress: string | null;
    arguments: string[] | null;
    transaction: Transaction;
    function: string | null;
}

interface Transaction {
    from: string;
    gas: string;
    value: string | null;
    input: string;
    nonce: string;
}

async function getLastDeployments(broadcastFolder: string): Promise<Map<string, DeploymentObject>> {
    const newDeployments = new Map<string, DeploymentObject>();
    const scriptDirs = fs.readdirSync(broadcastFolder, {withFileTypes: true}).filter((dirent) => dirent.isDirectory());

    for (const scriptDir of scriptDirs) {
        const chainDirs = fs
            .readdirSync(path.join(broadcastFolder, scriptDir.name), {withFileTypes: true})
            .filter((dirent) => dirent.isDirectory());

        for (const chainId of chainDirs) {
            const filepath = path.join(broadcastFolder, scriptDir.name, chainId.name, "run-latest.json");
            const data = fs.readFileSync(filepath, "utf-8");
            const fileContent: FileContent = JSON.parse(data);

            const transactionPerDeployments = new Map<string, TransactionResult>();
            for (const transactionResult of fileContent.transactions) {
                if (transactionResult.contractAddress) {
                    transactionPerDeployments.set(ethers.utils.getAddress(transactionResult.contractAddress), transactionResult);
                }
            }

            const returns = fileContent.returns;
            if (returns && returns.newDeployments && returns.newDeployments.internal_type === "struct DeployerDeployment[]") {
                const value = returns.newDeployments.value.toString();
                const regexResult = [...value.matchAll(/\((.+?)\)/g)];

                for (const match of regexResult) {
                    const entry = match[1].replace(/\\"/g, "").replace(/""/g, "");
                    const [name, address, bytecode, args_data, artifact_full_path] = entry
                        .split(", ")
                        .map((value: string) => value.replace(/^"|"$/g, ""));

                    const checksumAddress = ethers.utils.getAddress(address);

                    const [artifact_path, contract_name] = artifact_full_path.split(":");
                    const transactionResult = transactionPerDeployments.get(checksumAddress);

                    const deploymentObject: DeploymentObject = {
                        name,
                        address: checksumAddress,
                        bytecode,
                        args_data,
                        tx_hash: transactionResult ? transactionResult.hash : "",
                        args: transactionResult ? transactionResult.arguments : null,
                        data: transactionResult ? transactionResult.transaction.input : "",
                        contract_name: contract_name ?? null,
                        artifact_path,
                        artifact_full_path,
                        chain_id: chainId.name,
                    };

                    newDeployments.set(name, deploymentObject);
                }
            }
        }
    }
    return newDeployments;
}

async function generateDeployments(deploymentFolder: string, artifactsFolder: string, newDeployments: Map<string, DeploymentObject>) {
    for (const [_, value] of newDeployments) {
        const folderPath = path.join(deploymentFolder, value.chain_id);
        fs.mkdirSync(folderPath, {recursive: true});

        let deployment: Partial<DeploymentArtifact>;

        const deploymentFilePath = path.join(folderPath, `${value.name}.json`);

        if (value.artifact_path) {
            const artifactPath = path.join(artifactsFolder, value.artifact_path);
            const contractFilename = value.contract_name
                ? `${value.contract_name}.json`
                : fs.readdirSync(artifactPath).find((file) => file.endsWith(".json"))!;
            const artifactFilePath = path.join(artifactPath, contractFilename);

            const artifactData = fs.readFileSync(artifactFilePath, "utf-8");
            const artifact = JSON.parse(artifactData);

            deployment = {
                address: value.address as `0x${string}`,
                abi: artifact.abi,
                bytecode: value.bytecode,
                args_data: value.args_data,
                tx_hash: value.tx_hash,
                args: value.args,
                data: value.data,
                artifact_path: value.artifact_path,
                artifact_full_path: value.artifact_full_path,
            };
        } else {
            deployment = {
                abi: [],
                address: value.address as `0x${string}`,
                bytecode: "",
                args_data: value.args_data,
                tx_hash: value.tx_hash,
                args: value.args,
                data: value.data,
                artifact_path: "",
                artifact_full_path: "",
            };
        }
        
        const deploymentData = JSON.stringify(deployment, null, 2);

        console.log(`Writing deployment file ${deploymentFilePath}...`);
        fs.writeFileSync(deploymentFilePath, deploymentData);
    }
}

export const task: TaskFunction = async (_: TaskArgs, tooling: Tooling) => {
    const broadcastsFolder = path.join(tooling.projectRoot, tooling.config.foundry.broadcast);

    if (!fs.existsSync(broadcastsFolder)) {
        return;
    }

    const deploymentsFolder = path.join(tooling.projectRoot, tooling.config.deploymentFolder);
    const artifactsFolder = path.join(tooling.projectRoot, tooling.config.foundry.out);

    const newDeployments = await getLastDeployments(broadcastsFolder);
    await generateDeployments(deploymentsFolder, artifactsFolder, newDeployments);

    console.log(chalk.green("Deployment files generated successfully."));
};
