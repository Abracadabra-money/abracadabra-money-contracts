import {Glob} from "bun";
import * as fs from "fs";
import * as path from "path";
import {
    type Artifact,
    type Deployment,
    type Network,
    type NetworkConfig,
    type DeploymentWithFileInfo,
    type AddressEntry,
    type AddressSections,
    type Config,
    AddressScopeType,
    NetworkName,
    getNetworkNameEnumKey,
} from "./types";
import {ethers} from "ethers";
import chalk from "chalk";
import baseConfig from "./config";
import {getForgeConfig} from "./foundry";
import {join, extname} from "path";

const providers: {[key: string]: any} = {};

let privateKey = process.env.PRIVATE_KEY;
if (!privateKey) {
    privateKey = ethers.Wallet.fromMnemonic("test test test test test test test test test test test junk").privateKey;
}

let config = baseConfig as Config;
let signer: ethers.Signer;
let network = {} as Network;

const init = async () => {
    (config.projectRoot = process.cwd()), (config.foundry = await getForgeConfig());

    // Load default congigurations
    const defaultAddressConfigs = JSON.parse(fs.readFileSync(`./config/default.json`, "utf8")) as {[key: string]: AddressEntry[]};
    const defaultAddresses: AddressSections = {};

    for (const sectionName of Object.keys(defaultAddressConfigs)) {
        defaultAddresses[sectionName] = {};

        for (const entry of defaultAddressConfigs[sectionName]) {
            defaultAddresses[sectionName][entry.key] = entry;
        }
    }

    config.defaultAddresses = defaultAddresses;

    for (const networkName of Object.values(NetworkName)) {
        config.networks[networkName].name = networkName;

        const addressConfigs = JSON.parse(fs.readFileSync(`./config/${networkName}.json`, "utf8")) as {[key: string]: AddressEntry[]};
        config.networks[networkName].addresses = {};

        for (const sectionName of Object.keys(addressConfigs)) {
            const sectionDefaultEntries = Object.assign({}, defaultAddresses[sectionName]);
            config.networks[networkName].addresses[sectionName] = sectionDefaultEntries;

            for (const entry of addressConfigs[sectionName]) {
                config.networks[networkName].addresses[sectionName][entry.key] = entry;
            }
        }
    }
};

const changeNetwork = (networkName: NetworkName): NetworkConfig => {
    if (!config.networks[networkName]) {
        throw new Error(`changeNetwork: Couldn't find network '${networkName}'`);
    }

    if (!providers[network.name]) {
        providers[network.name] = network.provider;
    }

    network.name = networkName;
    network.config = config.networks[networkName];

    if (!providers[networkName]) {
        providers[networkName] = new ethers.providers.JsonRpcProvider(config.networks[networkName].url);
    }

    network.provider = providers[networkName];
    signer = new ethers.Wallet(privateKey, network.provider);

    return network.config;
};

const getNetworkConfigByName = (name: NetworkName): NetworkConfig => {
    if (!config.networks[name]) {
        throw new Error(`Network ${name} not found`);
    }

    return config.networks[name];
};

const getNetworkConfigByChainId = (chainId: number): NetworkConfig => {
    const foundConfig = findNetworkConfigByName((config) => config.chainId === chainId);

    if (!foundConfig) {
        console.error(`ChainId: ${chainId} not found`);
        process.exit(1);
    }

    return foundConfig;
};

const getNetworkConfigByLzChainId = (lzChainId: number): NetworkConfig => {
    const foundConfig = findNetworkConfigByName((config) => config.lzChainId === lzChainId);

    if (!foundConfig) {
        console.error(`LzChainId: ${lzChainId} not found`);
        process.exit(1);
    }

    return foundConfig;
};

const getAllNetworks = () => {
    return Object.values(NetworkName);
};

const getAllNetworksLzSupported = (): NetworkName[] => {
    return Object.values(NetworkName).filter((name) => !config.networks[name as NetworkName].extra?.lzUnsupported) as NetworkName[];
};

const findNetworkConfigByName = (predicate: (c: NetworkConfig) => boolean): NetworkConfig | null => {
    for (const [_, c] of Object.entries(config.networks)) {
        if (predicate(c)) {
            return c;
        }
    }

    return null;
};

const getLzChainIdByName = (name: NetworkName): number => {
    const NetworkConfigWithName = getNetworkConfigByName(name);

    if (!NetworkConfigWithName.lzChainId) {
        console.error(`Network ${name} does not have a lzChainId`);
        process.exit(1);
    }

    return NetworkConfigWithName.lzChainId;
};

const getChainIdByName = (name: NetworkName): number => {
    return getNetworkConfigByName(name).chainId;
};

const getArtifact = (artifact: string): Artifact => {
    const [filepath, name] = artifact.split(":");
    const file = `./${config.foundry.out}/${path.basename(filepath)}/${name}.json`;

    if (!fs.existsSync(file)) {
        console.error(`Artifact ${artifact} not found (${file})`);
        process.exit(1);
    }

    return JSON.parse(fs.readFileSync(file, "utf8"));
};

const deploymentExists = (name: string, chainId: number): boolean => {
    return fs.existsSync(`./deployments/${chainId}/${name}.json`);
};

const tryGetDeployment = (name: string, chainId: number): Deployment | undefined => {
    const file = `./deployments/${chainId}/${name}.json`;

    if (fs.existsSync(file)) {
        return JSON.parse(fs.readFileSync(file, "utf8"));
    }
};

const getDeployment = (name: string, chainId: number): Deployment => {
    const file = `./deployments/${chainId}/${name}.json`;

    if (!fs.existsSync(file)) {
        console.error(`ChainId: ${chainId} does not have a deployment for ${name}. (${file} not found)`);
        process.exit(1);
    }

    return JSON.parse(fs.readFileSync(file, "utf8"));
};

const getDeploymentWithSuggestions = async (name: string, chainId: number): Promise<Deployment> => {
    const file = `./deployments/${chainId}/${name}.json`;

    if (!fs.existsSync(file)) {
        const suggestions = await _findSimilarDeploymentNames(name, chainId);
        let errorMessage = `ChainId: ${chainId} does not have a deployment for ${name}. (${file} not found)`;

        if (suggestions.length > 0) {
            errorMessage += `\nDid you mean one of these?`;
            suggestions.forEach((suggestion) => {
                errorMessage += `\n  - ${suggestion}`;
            });
        }

        console.error(errorMessage);
        process.exit(1);
    }

    return JSON.parse(fs.readFileSync(file, "utf8"));
};

const getDeploymentWithSuggestionsAndSimilars = async (
    name: string,
    chainId: number
): Promise<{deployment?: Deployment; suggestions: string[]}> => {
    const file = `./deployments/${chainId}/${name}.json`;
    let deployment: Deployment | undefined;
    let suggestions: string[] = [];

    if (fs.existsSync(file)) {
        deployment = JSON.parse(fs.readFileSync(file, "utf8"));
    }

    suggestions = await _findSimilarDeploymentNames(name, chainId);
    // Remove current deployment from suggestions if it exists
    suggestions = suggestions.filter(suggestion => suggestion !== name);

    if (!deployment) {
        let errorMessage = `ChainId: ${chainId} does not have a deployment for ${name}. (${file} not found)`;

        if (suggestions.length > 0) {
            errorMessage += `\nDid you mean one of these?`;
            suggestions.forEach((suggestion) => {
                errorMessage += `\n  - ${suggestion}`;
            });
        }

        console.error(errorMessage);
        process.exit(1);
    }

    return {deployment, suggestions};
};

const _findSimilarContractNames = async (name: string): Promise<string[]> => {
    const glob = new Glob("**/*.sol");
    const files = await Array.fromAsync(glob.scan(config.foundry.src));
    const contractNames = files.map((file) => path.basename(file, ".sol"));
    return contractNames.filter(
        (contractName) => contractName.toLowerCase().includes(name.toLowerCase()) || name.toLowerCase().includes(contractName.toLowerCase())
    );
};

const getAllDeploymentsByChainId = async (chainId: number): Promise<DeploymentWithFileInfo[]> => {
    const deploymentRoot = path.join(config.projectRoot, config.deploymentFolder);
    const chainDeployementRoot = path.join(deploymentRoot, chainId.toString());

    const glob = new Glob("*.json");
    const files = await Array.fromAsync(glob.scan(chainDeployementRoot));

    return files.map((file) => {
        file = path.join(chainDeployementRoot, file);
        return {
            name: path.basename(file),
            path: file,
            ...JSON.parse(fs.readFileSync(file, "utf8")),
        } as DeploymentWithFileInfo;
    });
};

const getAbi = async (artifactName: string): Promise<ethers.ContractInterface> => {
    const glob = new Glob(`**/${artifactName}.json`);

    if (!config.foundry.out || !fs.existsSync(config.foundry.out)) {
        console.error(`Foundry output folder ${config.foundry.out} not found. Make sure to build using 'bun b' first.`);
        process.exit(1);
    }

    const file = (await Array.fromAsync(glob.scan(`${config.foundry.out}`)))[0];

    if (!file) {
        console.error(`Artifact ${artifactName} not found inside ${config.foundry.out}/ folder`);
        process.exit(1);
    }

    const filePath = `${config.foundry.out}/${file}`;
    if (!fs.existsSync(filePath)) {
        console.error(`File not found: ${filePath}`);
        process.exit(1);
    }

    return JSON.parse(fs.readFileSync(filePath, "utf8")).abi;
};

const getDeployer = async (): Promise<ethers.Signer> => {
    return signer;
};

const getContractAt = async (artifactNameOrAbi: string | ethers.ContractInterface, address: `0x${string}`): Promise<ethers.Contract> => {
    if (!address) {
        throw new Error(`Address not defined for contract ${artifactNameOrAbi.toString()}`);
    }

    if (typeof artifactNameOrAbi === "string") {
        const abi = await getAbi(artifactNameOrAbi);
        return new ethers.Contract(address, abi, signer);
    }

    return new ethers.Contract(address, artifactNameOrAbi as ethers.ContractInterface, signer);
};

const getContract = async (name: string, chainId?: number): Promise<ethers.Contract> => {
    const previousNetwork = getNetworkConfigByChainId(network.config.chainId);
    const currentNetwork = getNetworkConfigByChainId(chainId || previousNetwork.chainId);

    if (!chainId) {
        console.error("No network specified, use `changeNetwork` to switch network or specify --network parameter.");
        process.exit(1);
    }

    if (chainId !== previousNetwork.chainId) {
        await changeNetwork(currentNetwork.name);
    }

    const deployment = await getDeployment(name, chainId);
    const contract = new ethers.Contract(deployment.address, deployment.abi, signer);

    if (chainId !== previousNetwork.chainId) {
        await changeNetwork(previousNetwork.name);
    }

    return contract;
};

const getProvider = (): ethers.providers.JsonRpcProvider => {
    return network.provider;
};

const getDefaultAddressByLabel = (label: string): `0x${string}` | undefined => {
    return config.defaultAddresses?.["addresses"][label]?.value as `0x${string}`;
};

const getLabelByAddress = (networkName: NetworkName, address: `0x${string}`): string | undefined => {
    const addressesSection = getNetworkConfigByName(networkName)?.addresses?.["addresses"];

    if (addressesSection) {
        return Object.values(addressesSection).find((entry) => entry.value === address)?.key;
    }
};

const getAddressByLabel = (networkName: NetworkName, label: string): `0x${string}` | undefined => {
    const NetworkConfigWithName = getNetworkConfigByName(networkName);
    let address: `0x${string}` | undefined = NetworkConfigWithName.addresses?.addresses[label]?.value;

    if (!address) {
        const matchingLabels = Object.keys(NetworkConfigWithName.addresses?.addresses || {}).filter(
            (key) => key.toLowerCase() === label.toLowerCase()
        );

        if (matchingLabels.length > 1) {
            throw new Error(`Multiple case-insensitive matches found for label: ${label}`);
        }

        const matchedLabel = matchingLabels[0];
        address = matchedLabel ? NetworkConfigWithName.addresses?.addresses[matchedLabel]?.value : undefined;
    }

    return address && (ethers.utils.getAddress(address) as `0x${string}`);
};

const getFormatedAddressLabelScopeAnnotation = (networkName: NetworkName, label: string): string | undefined => {
    const scope = getAddressLabelScope(networkName, label);

    switch (scope) {
        case AddressScopeType.DEFAULT:
            return chalk.gray("[default]");
        case AddressScopeType.OVERRIDDEN:
            return chalk.blue("[overridden]");
        case AddressScopeType.SPECIFIC:
            return chalk.yellow("[specific]");
        default:
            throw new Error(`Unknown address scope: ${scope}`);
    }
};

const getLabeledAddress = (networkName: NetworkName, labelOrAddress: string | `0x${string}`): string | `0x${string}` | undefined => {
    if (labelOrAddress.startsWith("0x")) {
        const label = getLabelByAddress(networkName, labelOrAddress as `0x${string}`);
        return (
            (label && `${labelOrAddress} (${label}) ${getFormatedAddressLabelScopeAnnotation(networkName, label)}`) ||
            (labelOrAddress as `0x${string}`)
        );
    }

    const address = getAddressByLabel(networkName, labelOrAddress as string);
    return (
        (address && `${address} (${labelOrAddress}) ${getFormatedAddressLabelScopeAnnotation(networkName, labelOrAddress as string)}`) ||
        undefined
    );
};

const getAddressLabelScope = (networkName: NetworkName, label: string): AddressScopeType => {
    const defaultAddress = getDefaultAddressByLabel(label);
    const address = getAddressByLabel(networkName, label);

    if (defaultAddress) {
        if (address === defaultAddress) {
            return AddressScopeType.DEFAULT;
        }

        return AddressScopeType.OVERRIDDEN;
    }

    return AddressScopeType.SPECIFIC;
};

export const CHAIN_NETWORK_NAME_PER_CHAIN_ID = Object.values(NetworkName).reduce((acc, networkName) => {
    return {...acc, [config.networks[networkName as NetworkName].chainId]: getNetworkNameEnumKey(networkName)};
}, {}) as {[chainId: number]: string};

const _findSimilarDeploymentNames = async (targetName: string, chainId: number, maxSuggestions: number = 20): Promise<string[]> => {
    const deployments = await getAllDeploymentsByChainId(chainId);
    const availableNames = deployments.map((d) => path.basename(d.name as string, ".json"));

    const similarNames = availableNames.filter((name) => name.toLowerCase().includes(targetName.toLowerCase()));

    return similarNames.slice(0, maxSuggestions);
};

export async function getSolFiles(dir: string): Promise<string[]> {
    let results: string[] = [];
    const entries = await fs.readdirSync(dir, {withFileTypes: true});

    for (const entry of entries) {
        const fullPath = join(dir, entry.name);
        if (entry.isDirectory()) {
            results = results.concat(await getSolFiles(fullPath));
        } else if (extname(entry.name) === ".sol") {
            results.push(fullPath);
        }
    }

    return results;
}

export const tooling = {
    config,
    network,
    init,
    changeNetwork,
    getNetworkConfigByName,
    getNetworkConfigByChainId,
    getNetworkConfigByLzChainId,
    getAllNetworks,
    getAllNetworksLzSupported,
    findNetworkConfigByName,
    getLzChainIdByName,
    getChainIdByName,
    getArtifact,
    deploymentExists,
    getAllDeploymentsByChainId,
    getAbi,
    getDeployer,
    getContractAt,
    getContract,
    getProvider,
    getDefaultAddressByLabel,
    getLabelByAddress,
    getAddressByLabel,
    getFormatedAddressLabelScopeAnnotation,
    getLabeledAddress,
    getAddressLabelScope,
    getDeployment,
    getDeploymentWithSuggestions,
    getDeploymentWithSuggestionsAndSimilars,
    tryGetDeployment,
    getSolFiles,
};

export type Tooling = typeof tooling;
