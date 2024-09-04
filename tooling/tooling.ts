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
} from "./types";
import {ethers} from "ethers";
import chalk from "chalk";
import baseConfig from "./config";
import {getForgeConfig} from "./foundry";

const providers: {[key: string]: any} = {};

let privateKey = process.env.PRIVATE_KEY;
if (!privateKey) {
    privateKey = ethers.Wallet.fromMnemonic("test test test test test test test test test test test junk").privateKey;
}

let config = baseConfig as Config;
let signer: ethers.Signer;
let network = {} as Network;

export const init = async () => {
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

    for (const networkName of Object.keys(config.networks)) {
        config.networks[networkName].name = networkName;

        if (!config.networks[networkName].enumName) {
            config.networks[networkName].enumName = `${networkName.charAt(0).toUpperCase()}${networkName?.slice(1)}`;
        }

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

export const changeNetwork = (networkName: string): NetworkConfig => {
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

export const getNetworkConfigByName = (name: string): NetworkConfig => {
    if (!config.networks[name]) {
        throw new Error(`Network ${name} not found`);
    }

    return config.networks[name];
};

export const getNetworkConfigByChainId = (chainId: number): NetworkConfig => {
    const foundConfig = findNetworkConfigByName((config) => config.chainId === chainId);

    if (!foundConfig) {
        console.error(`ChainId: ${chainId} not found`);
        process.exit(1);
    }

    return foundConfig;
};

export const getNetworkConfigByLzChainId = (lzChainId: number): NetworkConfig => {
    const foundConfig = findNetworkConfigByName((config) => config.lzChainId === lzChainId);

    if (!foundConfig) {
        console.error(`LzChainId: ${lzChainId} not found`);
        process.exit(1);
    }

    return foundConfig;
};

export const getAllNetworks = () => {
    return Object.keys(config.networks);
};

export const getAllNetworksLzMimSupported = () => {
    return Object.keys(config.networks).filter((name) => !config.networks[name].extra?.mimLzUnsupported);
};

export const findNetworkConfigByName = (predicate: (c: NetworkConfig) => boolean): NetworkConfig | null => {
    for (const [_, c] of Object.entries(config.networks)) {
        if (predicate(c)) {
            return c;
        }
    }

    return null;
};

export const getLzChainIdByName = (name: string): number => {
    const NetworkConfigWithName = getNetworkConfigByName(name);

    if (!NetworkConfigWithName.lzChainId) {
        console.error(`Network ${name} does not have a lzChainId`);
        process.exit(1);
    }

    return NetworkConfigWithName.lzChainId;
};

export const getChainIdByName = (name: string): number => {
    return getNetworkConfigByName(name).chainId;
};

export const getArtifact = (artifact: string): Artifact => {
    const [filepath, name] = artifact.split(":");
    const file = `./${config.foundry.out}/${path.basename(filepath)}/${name}.json`;

    if (!fs.existsSync(file)) {
        console.error(`Artifact ${artifact} not found (${file})`);
        process.exit(1);
    }

    return JSON.parse(fs.readFileSync(file, "utf8"));
};

export const deploymentExists = (name: string, chainId: number): boolean => {
    return fs.existsSync(`./deployments/${chainId}/${name}.json`);
};

export const tryGetDeployment = (name: string, chainId: number): Deployment | undefined => {
    const file = `./deployments/${chainId}/${name}.json`;

    if (fs.existsSync(file)) {
        return JSON.parse(fs.readFileSync(file, "utf8"));
    }
};

export const getDeployment = (name: string, chainId: number): Deployment => {
    const file = `./deployments/${chainId}/${name}.json`;

    if (!fs.existsSync(file)) {
        console.error(`ChainId: ${chainId} does not have a deployment for ${name}. (${file} not found)`);
        process.exit(1);
    }

    return JSON.parse(fs.readFileSync(file, "utf8"));
};

export const getAllDeploymentsByChainId = async (chainId: number): Promise<DeploymentWithFileInfo[]> => {
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

export const getAbi = async (artifactName: string): Promise<ethers.ContractInterface> => {
    const glob = new Glob(`**/${artifactName}.json`);
    let file = (await Array.fromAsync(glob.scan(`${config.foundry.out}`)))[0];

    if (!file) {
        console.error(`Artifact ${artifactName} not found inside ${config.foundry.out}/ folder`);
        process.exit(1);
    }

    return JSON.parse(fs.readFileSync(`${config.foundry.out}/${file}`, "utf8")).abi;
};

export const getDeployer = async (): Promise<ethers.Signer> => {
    return signer;
};

export const getContractAt = async (
    artifactNameOrAbi: string | ethers.ContractInterface,
    address: `0x${string}`
): Promise<ethers.Contract> => {
    if (!address) {
        throw new Error(`Address not defined for contract ${artifactNameOrAbi.toString()}`);
    }

    if (typeof artifactNameOrAbi === "string") {
        const abi = await getAbi(artifactNameOrAbi);
        return new ethers.Contract(address, abi, signer);
    }

    return new ethers.Contract(address, artifactNameOrAbi as ethers.ContractInterface, signer);
};

export const getContract = async (name: string, chainId?: number): Promise<ethers.Contract> => {
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

export const getProvider = (): ethers.providers.JsonRpcProvider => {
    return network.provider;
};

export const getDefaultAddressByLabel = (label: string): `0x${string}` | undefined => {
    return config.defaultAddresses?.["addresses"][label]?.value as `0x${string}`;
};

export const getLabelByAddress = (networkName: string, address: `0x${string}`): string | undefined => {
    const addressesSection = getNetworkConfigByName(networkName)?.addresses?.["addresses"];

    if (addressesSection) {
        return Object.values(addressesSection).find((entry) => entry.value === address)?.key;
    }
};

export const getAddressByLabel = (networkName: string, label: string): `0x${string}` | undefined => {
    const NetworkConfigWithName = getNetworkConfigByName(networkName);
    const address = NetworkConfigWithName.addresses?.addresses[label]?.value;

    return address && (ethers.utils.getAddress(address) as `0x${string}`);
};

export const getFormatedAddressLabelScopeAnnotation = (networkName: string, label: string): string | undefined => {
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

export const getLabeledAddress = (networkName: string, labelOrAddress: string | `0x${string}`): string | `0x${string}` | undefined => {
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

export const getAddressLabelScope = (networkName: string, label: string): AddressScopeType => {
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

export const tooling = {
    config,
    network,
    init,
    changeNetwork,
    getNetworkConfigByName,
    getNetworkConfigByChainId,
    getNetworkConfigByLzChainId,
    getAllNetworks,
    getAllNetworksLzMimSupported,
    findNetworkConfigByName,
    getLzChainIdByName,
    getChainIdByName,
    getArtifact,
    deploymentExists,
    tryGetDeployment,
    getDeployment,
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
};

export type Tooling = typeof tooling;
