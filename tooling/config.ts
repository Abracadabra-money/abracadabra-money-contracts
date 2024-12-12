import "dotenv-defaults/config";
import {NetworkName, WalletType, type BaseConfig} from "./types";
import type { BaseLzDeployementConfigs } from "./tasks/utils/lz";

const config: BaseConfig = {
    deploymentFolder: "deployments",
    defaultNetwork: NetworkName.Mainnet,
    walletType: process.env.WALLET_TYPE as WalletType,
    walletConfig: {},
    networks: {
        mainnet: {
            url: process.env.MAINNET_RPC_URL,
            api_key: process.env.MAINNET_ETHERSCAN_KEY,
            chainId: 1,
            lzChainId: 101,
        },
        bsc: {
            url: process.env.BSC_RPC_URL,
            api_key: process.env.BSC_ETHERSCAN_KEY,
            chainId: 56,
            lzChainId: 102,
            disableVerifyOnDeploy: true,
        },
        avalanche: {
            url: process.env.AVALANCHE_RPC_URL,
            api_key: process.env.AVALANCHE_ETHERSCAN_KEY,
            chainId: 43114,
            lzChainId: 106,
        },
        polygon: {
            url: process.env.POLYGON_RPC_URL,
            api_key: process.env.POLYGON_ETHERSCAN_KEY,
            chainId: 137,
            lzChainId: 109,
        },
        arbitrum: {
            url: process.env.ARBITRUM_RPC_URL,
            api_key: process.env.ARBITRUM_ETHERSCAN_KEY,
            chainId: 42161,
            lzChainId: 110,
        },
        optimism: {
            url: process.env.OPTIMISM_RPC_URL,
            api_key: process.env.OPTIMISM_ETHERSCAN_KEY,
            chainId: 10,
            lzChainId: 111,
            forgeDeployExtraArgs: "--legacy",
        },
        fantom: {
            url: process.env.FANTOM_RPC_URL,
            api_key: process.env.FTMSCAN_ETHERSCAN_KEY,
            chainId: 250,
            lzChainId: 112,
            profile: "evm_paris",
        },
        moonriver: {
            url: process.env.MOONRIVER_RPC_URL,
            api_key: process.env.MOONRIVER_ETHERSCAN_KEY,
            chainId: 1285,
            lzChainId: 167,
        },
        kava: {
            api_key: null,
            url: process.env.KAVA_RPC_URL,
            chainId: 2222,
            lzChainId: 177,
            profile: "evm_paris",
            forgeDeployExtraArgs: "--legacy",
        },
        linea: {
            url: process.env.LINEA_RPC_URL,
            api_key: process.env.LINEA_ETHERSCAN_KEY,
            chainId: 59144,
            lzChainId: 183,
            profile: "evm_london",
        },
        base: {
            url: process.env.BASE_RPC_URL,
            api_key: process.env.BASE_ETHERSCAN_KEY,
            chainId: 8453,
            lzChainId: 184,
        },
        bera: {
            url: process.env.BERA_RPC_URL,
            api_key: "verifyContract",
            chainId: 80084,
            forgeVerifyExtraArgs: "--retries 2 --verifier-url https://api.routescan.io/v2/network/testnet/evm/80084/etherscan",
            forgeDeployExtraArgs: "--legacy --verifier-url https://api.routescan.io/v2/network/testnet/evm/80084/etherscan",
            disableSourcify: true, // sourcify not supported on bartio testnet
            disableVerifyOnDeploy: true, // verify on deploy not supported on bartio testnet
        },
        blast: {
            url: process.env.BLAST_RPC_URL,
            api_key: process.env.BLAST_ETHERSCAN_KEY,
            chainId: 81457,
            lzChainId: 243,
            forgeDeployExtraArgs: "--skip-simulation",
            disableSourcify: true,
            disableVerifyOnDeploy: true, // not supported on blast because we need to be skipping simulation for blast-precompiles.
        },
        hyper: {
            url: process.env.HYPER_RPC_URL,
            api_key: process.env.HYPER_ETHERSCAN_KEY,
            chainId: 998,
            forgeDeployExtraArgs: "--skip-simulation",
            disableSourcify: true,
            disableVerifyOnDeploy: true,
            disableScript: true,
        },
        sei: {
            url: process.env.SEI_RPC_URL,
            api_key: process.env.SEI_ETHERSCAN_KEY,
            forgeVerifyExtraArgs: "--retries 2 --verifier-url https://seitrace.com/pacific-1/api",
            forgeDeployExtraArgs: "--verifier-url https://seitrace.com/pacific-1/api",
            chainId: 1329,
            disableSourcify: true,
            disableVerifyOnDeploy: true, // not supported on blast because we need to be skipping simulation for blast-precompiles.
        },
    },
};

export const LZ_DEPLOYEMENT_CONFIG: BaseLzDeployementConfigs = {
    MIM: {
        [NetworkName.Mainnet]: {
            isNative: true,
            token: "mim",
            useWrapper: true,
            owner: "safe.main",
        },
        [NetworkName.BSC]: {
            token: "mim",
            useWrapper: true,
            useAnyswapMinterBurner: true,
            owner: "safe.main",
        },
        [NetworkName.Polygon]: {
            token: "mim",
            useWrapper: true,
            useAnyswapMinterBurner: true,
            owner: "safe.main",
        },
        [NetworkName.Fantom]: {
            token: "mim",
            useWrapper: true,
            useAnyswapMinterBurner: true,
            owner: "safe.main",
        },
        [NetworkName.Optimism]: {
            token: "mim",
            useWrapper: true,
            useAnyswapMinterBurner: true,
            owner: "safe.main",
        },
        [NetworkName.Arbitrum]: {
            token: "mim",
            useWrapper: true,
            useAnyswapMinterBurner: true,
            owner: "safe.main",
        },
        [NetworkName.Avalanche]: {
            token: "mim",
            useWrapper: true,
            useAnyswapMinterBurner: true,
            owner: "safe.main",
        },
        [NetworkName.Moonriver]: {
            token: "mim",
            useWrapper: true,
            useAnyswapMinterBurner: true,
            owner: "safe.ops",
        },
        [NetworkName.Kava]: {
            token: "mim",
            useWrapper: true,
            owner: "safe.main",
        },
        [NetworkName.Base]: {
            token: "mim",
            useNativeFeeHandler: true,
            owner: "safe.ops",
        },
        [NetworkName.Linea]: {
            token: "mim",
            useNativeFeeHandler: true,
            owner: "safe.ops",
        },
        [NetworkName.Blast]: {
            token: "mim",
            useNativeFeeHandler: true,
            owner: "safe.main",
        },
    },

    SPELL: {
        [NetworkName.Mainnet]: {
            isNative: true,
            token: "spell",
            useNativeFeeHandler: true,
            owner: "safe.main",
        },
        [NetworkName.Fantom]: {
            token: "spellV2",
            useNativeFeeHandler: true,
            owner: "safe.main",
        },
        [NetworkName.Arbitrum]: {
            token: "spellV2",
            useNativeFeeHandler: true,
            owner: "safe.main",
        },
        [NetworkName.Avalanche]: {
            token: "spellV2",
            useNativeFeeHandler: true,
            owner: "safe.main",
        },
    },

    BSPELL: {
        [NetworkName.Arbitrum]: {
            isNative: true,
            token: "bspell",
            useNativeFeeHandler: true,
            owner: "safe.main",
        },
        [NetworkName.Avalanche]: {
            token: "bspell",
            useNativeFeeHandler: true,
            owner: "safe.main",
        },
        [NetworkName.Fantom]: {
            token: "bspell",
            useNativeFeeHandler: true,
            owner: "safe.main",
        },
        [NetworkName.Mainnet]: {
            token: "bspell",
            useNativeFeeHandler: true,
            owner: "safe.main",
        },
    },
};

export default config;
