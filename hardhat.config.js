const fs = require("fs");
require("@nomiclabs/hardhat-ethers");
require("@nomicfoundation/hardhat-foundry");
require("dotenv-defaults").config();
require("./tasks");
const { createProvider } = require("hardhat/internal/core/providers/construction");
const { getForgeConfig } = require("@nomicfoundation/hardhat-foundry/dist/src/foundry");

const foundry = getForgeConfig();

const accounts = [process.env.PRIVATE_KEY];

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  foundry,
  defaultNetwork: "localhost",
  solidity: {
    compilers: [
      {
        version: foundry.solc,
        settings: {
          optimizer: {
            enabled: foundry.optimizer,
            runs: foundry.optimizer_runs
          }
        }
      }
    ]
  },
  namedAccounts: {
    deployer: {
      default: 0,
    }
  },
  networks: {
    mainnet: {
      url: process.env.MAINNET_RPC_URL,
      api_key: process.env.MAINNET_ETHERSCAN_KEY,
      chainId: 1,
      accounts
    },
    bsc: {
      url: process.env.BSC_RPC_URL,
      api_key: process.env.BSC_ETHERSCAN_KEY,
      chainId: 56,
      accounts
    },
    avalanche: {
      url: process.env.AVALANCHE_RPC_URL,
      api_key: process.env.AVALANCHE_ETHERSCAN_KEY,
      chainId: 43114,
      accounts
    },
    polygon: {
      url: process.env.POLYGON_RPC_URL,
      api_key: process.env.POLYGON_ETHERSCAN_KEY,
      chainId: 137,
      accounts
    },
    arbitrum: {
      url: process.env.ARBITRUM_RPC_URL,
      api_key: process.env.ARBITRUM_ETHERSCAN_KEY,
      chainId: 42161,
      accounts
    },
    optimism: {
      url: process.env.OPTIMISM_RPC_URL,
      api_key: process.env.OPTIMISM_ETHERSCAN_KEY,
      chainId: 10,
      accounts
    },
    fantom: {
      url: process.env.FANTOM_RPC_URL,
      api_key: process.env.FTMSCAN_ETHERSCAN_KEY,
      chainId: 250,
      accounts
    },
  }
};

extendEnvironment((hre) => {
  hre.foundryDeployments = {
    get: async (name) => {
      const chainId = hre.network.config.chainId;
      const networkName = hre.network.name;
      const file = `./deployments/${chainId}/${name}.json`;

      if (!fs.existsSync(file)) {
        console.error(`Network ${networkName}, chainId: ${chainId} does not have a deployment for ${name}. (${file} not found)`)
        process.exit(1);
      }

      const deployment = JSON.parse(fs.readFileSync(file, 'utf8'));
      const signer = (await hre.ethers.getSigners())[0];
      return await ethers.getContractAt(deployment.abi, deployment.address, signer);
    }
  };

  // create all network providers so it's easy to switch between them.
  // Adapted from https://github.com/dmihal/hardhat-change-network/
  const providers = {};

  hre.getProvider = (name) => {
    if (!providers[name]) {
      providers[name] = createProvider(
        name,
        hre.config.networks[name],
        hre.config.paths,
        hre.artifacts,
      );
    }
    return providers[name];
  };

  hre.changeNetwork = (networkName) => {
    if (!hre.config.networks[networkName]) {
      throw new Error(`changeNetwork: Couldn't find network '${networkName}'`);
    }

    if (!providers[hre.network.name]) {
      providers[hre.network.name] = hre.network.provider;
    }

    hre.network.name = networkName;
    hre.network.config = hre.config.networks[networkName];

    if (!providers[networkName]) {
      providers[networkName] = createProvider(
        networkName,
        hre.config.networks[networkName],
        hre.config.paths,
        hre.artifacts,
      );
    }

    hre.network.provider = providers[networkName];

    if (hre.ethers) {
      const { EthersProviderWrapper } = require("@nomiclabs/hardhat-ethers/internal/ethers-provider-wrapper");
      hre.ethers.provider = new EthersProviderWrapper(hre.network.provider);
    }
  };
});
