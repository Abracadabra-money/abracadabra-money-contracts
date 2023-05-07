const { getForgeConfig } = require("@nomicfoundation/hardhat-foundry/dist/src/foundry");
require("dotenv-defaults").config();
require("./tasks");

const foundry = getForgeConfig();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  foundry,
  defaultNetwork: "mainnet",
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
  networks: {
    mainnet: {
      url: process.env.MAINNET_RPC_URL,
      api_key: process.env.MAINNET_ETHERSCAN_KEY,
      chainId: 1
    },
    bsc: {
      url: process.env.BSC_RPC_URL,
      api_key: process.env.BSC_ETHERSCAN_KEY,
      chainId: 56,
    },
    avalanche: {
      url: process.env.AVALANCHE_RPC_URL,
      api_key: process.env.AVALANCHE_ETHERSCAN_KEY,
      chainId: 43114,
    },
    polygon: {
      url: process.env.POLYGON_RPC_URL,
      api_key: process.env.POLYGON_ETHERSCAN_KEY,
      chainId: 137,
    },
    arbitrum: {
      url: process.env.ARBITRUM_RPC_URL,
      api_key: process.env.ARBITRUM_RPC_URL,
      chainId: 42161,
    },
    optimism: {
      url: process.env.OPTIMISM_RPC_URL,
      api_key: process.env.OPTIMISM_ETHERSCAN_KEY,
      chainId: 10,
    },
    fantom: {
      url: process.env.FANTOM_RPC_URL,
      api_key: process.env.FTMSCAN_ETHERSCAN_KEY,
      chainId: 250,
    },
  }
};
