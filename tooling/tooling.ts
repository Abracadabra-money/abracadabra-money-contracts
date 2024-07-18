import { $, Glob } from "bun";
import * as fs from "fs";
import * as path from "path";
import config from "./config";
import type { Artifact, Deployment, Network, NetworkConfig, NetworkConfigWithName, Tooling, DeploymentWithFileInfo, AddressSection, AddressEntry, AddressSections } from "./types";
import { ethers } from "ethers";

const providers: { [key: string]: any } = {};

let privateKey = process.env.PRIVATE_KEY;
if (!privateKey) {
  privateKey = ethers.Wallet.fromMnemonic("test test test test test test test test test test test junk").privateKey;
};

let signer: ethers.Signer;

const loadDefaultConfigurations = (): AddressSections => {
  const defaultAddressConfigs = JSON.parse(fs.readFileSync(`./config/all.json`, 'utf8')) as { [key: string]: AddressEntry[] };
  const defaultEntries: AddressSections = {};

  for (const sectionName of Object.keys(defaultAddressConfigs)) {
    defaultEntries[sectionName] = {};

    for (const entry of defaultAddressConfigs[sectionName]) {
      defaultEntries[sectionName][entry.key] = entry;
    }
  }

  return defaultEntries;
}

const loadConfigurations = () => {
  const defaultEntries = loadDefaultConfigurations();

  for (const network of Object.keys(config.networks)) {
    const addressConfigs = JSON.parse(fs.readFileSync(`./config/${network}.json`, 'utf8')) as { [key: string]: AddressEntry[] };
    config.networks[network].addresses = {};

    for (const sectionName of Object.keys(addressConfigs)) {
      const sectionDefaultEntries = Object.assign({}, defaultEntries[sectionName])
      config.networks[network].addresses[sectionName] = sectionDefaultEntries;

      for (const entry of addressConfigs[sectionName]) {
        config.networks[network].addresses[sectionName][entry.key] = entry;
      }
    }
  }
}

export const tooling: Tooling = {
  config: config,
  network: {} as Network,
  projectRoot: config.projectRoot,
  deploymentFolder: config.deploymentFolder,

  async init() {
    loadConfigurations();
  },

  changeNetwork(networkName: string) {
    if (!config.networks[networkName]) {
      throw new Error(`changeNetwork: Couldn't find network '${networkName}'`);
    }

    if (!providers[this.network.name]) {
      providers[this.network.name] = this.network.provider;
    }

    this.network.name = networkName;
    this.network.config = config.networks[networkName];

    if (!providers[networkName]) {
      providers[networkName] = new ethers.providers.JsonRpcProvider(config.networks[networkName].url);
    }

    this.network.provider = providers[networkName];
    signer = new ethers.Wallet(privateKey, this.network.provider);
  },

  getNetworkConfigByName(name: string): NetworkConfig {
    if (!config.networks[name]) {
      throw new Error(`Network ${name} not found`);
    }

    return config.networks[name];
  },

  getNetworkConfigByChainId(chainId: number): NetworkConfigWithName {
    const config = this.findNetworkConfig((config) => config.chainId === chainId);

    if (!config) {
      console.error(`ChainId: ${chainId} not found`);
      process.exit(1);
    }

    return config;
  },

  getNetworkConfigByLzChainId(lzChainId: number) {
    const config = this.findNetworkConfig((config) => config.lzChainId === lzChainId);

    if (!config) {
      console.error(`LzChainId: ${lzChainId} not found`);
      process.exit(1);
    }

    return config;
  },

  getAllNetworks() {
    return Object.keys(config.networks);
  },

  getAllNetworksLzMimSupported() {
    return Object.keys(config.networks).filter(name => !config.networks[name].extra?.mimLzUnsupported);
  },

  findNetworkConfig(predicate: (c: NetworkConfig) => boolean): NetworkConfigWithName | null {
    for (const [name, c] of Object.entries(config.networks)) {
      if (predicate(c)) {
        return {
          name,
          ...c
        };
      }
    }

    return null;
  },

  getLzChainIdByNetworkName(name: string): number {
    const networkConfig = this.getNetworkConfigByName(name)

    if (!networkConfig.lzChainId) {
      console.error(`Network ${name} does not have a lzChainId`);
      process.exit(1);
    }

    return networkConfig.lzChainId;
  },

  getChainIdByNetworkName(name: string): number {
    return this.getNetworkConfigByName(name).chainId;
  },

  getArtifact(artifact: string): Artifact {
    const [filepath, name] = artifact.split(':');
    const file = `./${config.foundry.out}/${path.basename(filepath)}/${name}.json`;

    if (!fs.existsSync(file)) {
      console.error(`Artifact ${artifact} not found (${file})`);
      process.exit(1);
    }

    return JSON.parse(fs.readFileSync(file, 'utf8'));
  },

  deploymentExists(name: string, chainId: number): boolean {
    return fs.existsSync(`./deployments/${chainId}/${name}.json`);
  },

  getDeployment(name: string, chainId: number): Deployment {
    const file = `./deployments/${chainId}/${name}.json`;

    if (!fs.existsSync(file)) {
      console.error(`ChainId: ${chainId} does not have a deployment for ${name}. (${file} not found)`);
      process.exit(1);
    }

    return JSON.parse(fs.readFileSync(file, 'utf8'));
  },

  async getAllDeploymentsByChainId(chainId: number): Promise<DeploymentWithFileInfo[]> {
    const deploymentRoot = path.join(tooling.projectRoot, tooling.deploymentFolder);
    const chainDeployementRoot = path.join(deploymentRoot, chainId.toString());

    const glob = new Glob("*.json");
    const files = await Array.fromAsync(glob.scan(chainDeployementRoot));

    return files.map(file => {
      return {
        __extra: {
          name: path.basename(file),
          path: file
        },
        ...JSON.parse(fs.readFileSync(path.join(chainDeployementRoot, file), 'utf8'))
      } as DeploymentWithFileInfo;
    });
  },

  async getAbi(artifactName: string): Promise<ethers.ContractInterface> {
    const glob = new Glob(`**/${artifactName}.json`);
    let file = (await Array.fromAsync(glob.scan(`${config.foundry.out}`)))[0];

    if (!file) {
      console.error(`Artifact ${artifactName} not found inside ${config.foundry.out}/ folder`);
      process.exit(1);
    }

    return (JSON.parse(fs.readFileSync(`${config.foundry.out}/${file}`, 'utf8'))).abi;
  },

  async getDeployer(): Promise<ethers.Signer> {
    return signer;
  },

  async getContractAt(artifactNameOrAbi: string | ethers.ContractInterface, address: `0x${string}`): Promise<ethers.Contract> {
    if (typeof artifactNameOrAbi === 'string') {
      const abi = await this.getAbi(artifactNameOrAbi);
      return new ethers.Contract(address, abi, signer);
    }

    return new ethers.Contract(address, artifactNameOrAbi as ethers.ContractInterface, signer);
  },

  async getContract(name: string, chainId?: number): Promise<ethers.Contract> {
    const previousNetwork = this.getNetworkConfigByChainId(this.network.config.chainId);
    const currentNetwork = this.getNetworkConfigByChainId(chainId || previousNetwork.chainId);

    if (!chainId) {
      console.error("No network specified, use `changeNetwork` to switch network or specify --network parameter.");
      process.exit(1);
    }

    if (chainId !== previousNetwork.chainId) {
      await this.changeNetwork(currentNetwork.name);
    }

    const deployment = await this.getDeployment(name, chainId);
    const contract = new ethers.Contract(deployment.address, deployment.abi, signer);

    if (chainId !== previousNetwork.chainId) {
      await this.changeNetwork(previousNetwork.name);
    }

    return contract;
  },

  getProvider(): ethers.providers.JsonRpcProvider {
    return this.network.provider;
  },

  getLabelByAddress(networkName: string, address: `0x${string}`): string | undefined {
    const addressesSection = this.getNetworkConfigByName(networkName)?.addresses?.['addresses'];

    if (addressesSection) {
      return Object.values(addressesSection).find(entry => entry.value === address)?.key
    }
  },

  getAddressByLabel(networkName: string, label: string): `0x${string}` | undefined {
    const networkConfig = this.getNetworkConfigByName(networkName);
    return networkConfig.addresses?.addresses[label]?.value as `0x${string}`;
  },
};
