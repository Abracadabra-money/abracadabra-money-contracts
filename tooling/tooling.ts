import { $, Glob } from "bun";
import * as fs from "fs";
import * as path from "path";
import config from "./config";
import type { Network, NetworkConfig, NetworkConfigWithName, Tooling } from "./types";
import { ethers } from "ethers";

const providers: { [key: string]: any } = {};
const addresses: { [key: string]: { [key: string]: string } } = {};

let privateKey = process.env.PRIVATE_KEY;
if (!privateKey) {
  privateKey = ethers.Wallet.fromMnemonic("test test test test test test test test test test test junk").privateKey;
};

let signer: ethers.Signer;

export const tooling: Tooling = {
  config: config,
  network: {} as Network,
  projectRoot: config.projectRoot,

  async init() {
    fs.readdirSync("./config").forEach((filename) => {
      if (filename.includes(".json")) {
        const network = filename.replace(".json", "");
        const items = JSON.parse(fs.readFileSync(`./config/${filename}`, 'utf8')).addresses;
        for (const item of items) {
          addresses[network] = addresses[network] || {};
          addresses[network][item.key] = item.value;
          addresses[network][item.value] = item.key;
        }
      }
    });
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

  getNetworkConfigByName(name: string): NetworkConfig | undefined {
    return config.networks[name];
  },

  getNetworkConfigByChainId(chainId: number): NetworkConfigWithName {
    const config = this.findNetworkConfig((config) => config.chainId === chainId);

    if (!config) {
      console.error(`ChainId: ${chainId} not found in hardhat.config.ts`);
      process.exit(1);
    }

    return config;
  },

  getNetworkConfigByLzChainId(lzChainId: number) {
    const config = this.findNetworkConfig((config) => config.lzChainId === lzChainId);

    if (!config) {
      console.error(`LzChainId: ${lzChainId} not found in hardhat.config.ts`);
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

  findNetworkConfig(predicate: (c: any) => boolean): NetworkConfigWithName | null {
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

  getLzChainIdByNetworkName(name: string): number | undefined {
    return this.getNetworkConfigByName(name)?.lzChainId;
  },

  getChainIdByNetworkName(name: string): number | undefined {
    return this.getNetworkConfigByName(name)?.chainId;
  },

  async getArtifact(artifact: string) {
    const [filepath, name] = artifact.split(':');
    const file = `./${config.foundry.out}/${path.basename(filepath)}/${name}.json`;

    if (!fs.existsSync(file)) {
      console.error(`Artifact ${artifact} not found (${file})`);
      process.exit(1);
    }

    return JSON.parse(fs.readFileSync(file, 'utf8'));
  },

  deploymentExists(name: string, chainId: number) {
    return fs.existsSync(`./deployments/${chainId}/${name}.json`);
  },

  async getDeployment(name: string, chainId: number) {
    const file = `./deployments/${chainId}/${name}.json`;

    if (!fs.existsSync(file)) {
      console.error(`ChainId: ${chainId} does not have a deployment for ${name}. (${file} not found)`);
      process.exit(1);
    }

    return JSON.parse(fs.readFileSync(file, 'utf8'));
  },

  async getAllDeploymentsByChainId(chainId: number) {
    const glob = new Glob("*.json");
    glob.scan(`./deployments/${chainId}`);
    const files = await Array.fromAsync(glob.scan(`./deployments/${chainId}`));

    return files.map(file => {
      return {
        __extra: {
          name: path.basename(file),
          path: file
        },
        ...JSON.parse(fs.readFileSync(file, 'utf8'))
      };
    });
  },

  async getAbi(artifactName: string) {
    const glob = new Glob(`**/${artifactName}.json`);
    const file = (await Array.fromAsync(glob.scan(`${config.foundry.out}`)))[0];

    if (!file) {
      console.error(`Artifact ${artifactName} not found inside ${config.foundry.out}/ folder`);
      process.exit(1);
    }

    return (JSON.parse(fs.readFileSync(file, 'utf8'))).abi;
  },

  async getDeployer() {
    return signer;
  },

  async getContractAt(artifactName: string, address: string) {
    const abi = await this.getAbi(artifactName);
    return new ethers.Contract(address, abi, signer);
  },

  async getContract(name: string, chainId?: number) {
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
    const contract = await this.getContractAt(deployment.abi, deployment.address);

    if (chainId !== previousNetwork.chainId) {
      await this.changeNetwork(previousNetwork.name);
    }

    return contract;
  },

  getLabelByAddress(networkName: string, address: string) {
    const label = addresses[networkName][address];

    if (!label) {
      return addresses['all'][address];
    }

    return label;
  },

  getAddressByLabel(networkName: string, label: string) {
    const address = addresses[networkName][label];
    if (!address) {
      return addresses['all'][label];
    }

    return address;
  },
};
