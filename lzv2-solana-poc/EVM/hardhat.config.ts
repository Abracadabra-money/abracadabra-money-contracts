// Get the environment configuration from .env file
//
// To make use of automatic environment setup:
// - Duplicate .env.example file and name it .env
// - Fill in the environment variables
import dotenv from 'dotenv'
import path from 'path'
import 'hardhat-deploy'
import 'hardhat-contract-sizer'
import '@nomiclabs/hardhat-ethers'
import '@layerzerolabs/toolbox-hardhat'
import { HardhatUserConfig, HttpNetworkAccountsUserConfig } from 'hardhat/types'

import { EndpointId } from '@layerzerolabs/lz-definitions'

dotenv.config({path: path.resolve(__dirname, '../.env')});

// If you prefer to be authenticated using a private key, set a PRIVATE_KEY environment variable
const EVM_ADMIN_PRIVATE_KEY = process.env.EVM_ADMIN_PRIVATE_KEY

const accounts: HttpNetworkAccountsUserConfig | undefined = EVM_ADMIN_PRIVATE_KEY ? [EVM_ADMIN_PRIVATE_KEY] : undefined

if (accounts == null) {
    console.warn(
        'Could not find PRIVATE_KEY environment variables. It will not be possible to execute transactions in your example.'
    )
}

const config: HardhatUserConfig = {
    paths: {
        cache: 'cache/hardhat',
    },
    solidity: {
        compilers: [
            {
                version: '0.8.22',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    defaultNetwork: "arbitrumSepoliaTestnet",
    networks: {
        arbitrumSepoliaTestnet: {
            eid: EndpointId.ARBSEP_V2_TESTNET,
            chainId: 421614,
            url: process.env.RPC_URL_ARBITRUMSEPOLIA || 'https://sepolia-rollup.arbitrum.io/rpc',
            accounts,
        },
    },
    namedAccounts: {
        deployer: {
            default: 0, // wallet address of index[0], of the mnemonic in .env
        },
    },
}

export default config
