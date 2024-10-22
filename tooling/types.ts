import {ethers} from "ethers";
import type {Tooling} from "./tooling";

export type Network = {
    name: NetworkName;
    config: NetworkConfig;
    provider: ethers.JsonRpcProvider;
};

export type BaseNetworkConfig = {
    chainId: number;
    url: string | undefined;

    // optionnal fields
    api_key?: string | undefined | null;
    lzChainId?: number;
    forgeDeployExtraArgs?: string;
    profile?: string;
    forgeVerifyExtraArgs?: string;
    disableSourcify?: boolean;
    disableVerifyOnDeploy?: boolean;
    disableScript?: boolean;
    extra?: any;
};

export type NetworkConfig = BaseNetworkConfig & {
    name: NetworkName;
    addresses: AddressSections;
};

export type AddressSections = {
    [key: string]: AddressSection;
};

export type AddressSection = {
    [key: string]: AddressEntry;
};

export type AddressEntry = {
    key: string;
    value: `0x${string}`;
};

export enum NetworkName {
    Mainnet = "mainnet",
    BSC = "bsc",
    Avalanche = "avalanche",
    Polygon = "polygon",
    Arbitrum = "arbitrum",
    Optimism = "optimism",
    Fantom = "fantom",
    Moonriver = "moonriver",
    Kava = "kava",
    Linea = "linea",
    Base = "base",
    Bera = "bera",
    Blast = "blast",
    Hyper = "hyper",
}

export const getNetworkNameEnumKey = (value: NetworkName) => {
    const reverseNetworkName = Object.fromEntries(Object.entries(NetworkName).map(([key, value]) => [value, key]));
    return reverseNetworkName[value] || undefined;
};

type BaseLzDeployementConfigs = {
    [key: string]: {
        [key in NetworkName]?: {
            nativeToken?: string;
            useWrapper?: boolean;
            useAnyswapMinterBurner?: boolean;
            owner: string;
            useNativeFeeHandler?: boolean;
        };
    };
};

export type LzDeployementConfig = {
    oft: `${string}_${string}_${string}`;
    precrime: `${string}_${string}_${string}`;
    feeHandler: `${string}_${string}_${string}`;
    minterBurner?: `${string}_${string}_${string}`;
    owner: `0x${string}`;
    nativeToken?: `0x${string}`;
};

export enum WalletType {
    PK = "pk",
    KEYSTORE = "keystore",
}

export type WalletConfig = {};

export type KeystoreWalletConfig = WalletConfig & {
    accountName: string;
};

export type BaseConfig = {
    deploymentFolder: string;
    defaultNetwork: NetworkName;
    walletType: WalletType;
    walletConfig: WalletConfig;
    networks: {
        [key in NetworkName]: BaseNetworkConfig;
    };
};

export type Config = BaseConfig & {
    projectRoot: string;
    foundry: FoundryConfig;
    defaultAddresses: AddressSections;
    networks: {
        [key in NetworkName]: NetworkConfig;
    };
};

export type FoundryConfig = {
    src: string;
    test: string;
    script: string;
    out: string;
    libs: string[];
    remappings: string[];
    auto_detect_remappings: boolean;
    libraries: any[];
    cache: boolean;
    cache_path: string;
    broadcast: string;
    allow_paths: any[];
    include_paths: any[];
    skip: any[];
    force: boolean;
    evm_version: string;
    gas_reports: string[];
    gas_reports_ignore: any[];
    solc: string;
    auto_detect_solc: boolean;
    offline: boolean;
    optimizer: boolean;
    optimizer_runs: number;
    optimizer_details: any;
    model_checker: any;
    verbosity: number;
    eth_rpc_url: string | null;
    eth_rpc_jwt: string | null;
    etherscan_api_key: string | null;
    ignored_error_codes: string[];
    ignored_warnings_from: any[];
    deny_warnings: boolean;
    match_test: string | null;
    no_match_test: string | null;
    match_contract: string;
    no_match_contract: string | null;
    match_path: string;
    no_match_path: string | null;
    fuzz: {
        runs: number;
        max_test_rejects: number;
        seed: string;
        dictionary_weight: number;
        include_storage: boolean;
        include_push_bytes: boolean;
        max_fuzz_dictionary_addresses: number;
        max_fuzz_dictionary_values: number;
        gas_report_samples: number;
        failure_persist_dir: string;
        failure_persist_file: string;
    };
    invariant: {
        runs: number;
        depth: number;
        fail_on_revert: boolean;
        call_override: boolean;
        dictionary_weight: number;
        include_storage: boolean;
        include_push_bytes: boolean;
        max_fuzz_dictionary_addresses: number;
        max_fuzz_dictionary_values: number;
        shrink_run_limit: number;
        max_assume_rejects: number;
        gas_report_samples: number;
        failure_persist_dir: string;
    };
    ffi: boolean;
    always_use_create_2_factory: boolean;
    prompt_timeout: number;
    sender: string;
    tx_origin: string;
    initial_balance: string;
    block_number: number;
    fork_block_number: number | null;
    chain_id: number | null;
    gas_limit: number;
    code_size_limit: number | null;
    gas_price: number | null;
    block_base_fee_per_gas: number;
    block_coinbase: string;
    block_timestamp: number;
    block_difficulty: number;
    block_prevrandao: string;
    block_gas_limit: number | null;
    memory_limit: number;
    extra_output: any[];
    extra_output_files: any[];
    names: boolean;
    sizes: boolean;
    via_ir: boolean;
    ast: boolean;
    rpc_storage_caching: {
        chains: string;
        endpoints: string;
    };
    no_storage_caching: boolean;
    no_rpc_rate_limit: boolean;
    use_literal_content: boolean;
    bytecode_hash: string;
    cbor_metadata: boolean;
    revert_strings: any;
    sparse_mode: boolean;
    build_info: boolean;
    build_info_path: string | null;
    fmt: {
        line_length: number;
        tab_width: number;
        bracket_spacing: boolean;
        int_types: string;
        multiline_func_header: string;
        quote_style: string;
        number_underscore: string;
        hex_underscore: string;
        single_line_statement_blocks: string;
        override_spacing: boolean;
        wrap_comments: boolean;
        ignore: any[];
        contract_new_lines: boolean;
        sort_imports: boolean;
    };
    doc: {
        out: string;
        title: string;
        book: string;
        homepage: string;
        ignore: any[];
    };
    fs_permissions: {
        access: string | boolean;
        path: string;
    }[];
    prague: boolean;
    isolate: boolean;
    disable_block_gas_limit: boolean;
    labels: any;
    unchecked_cheatcode_artifacts: boolean;
    create2_library_salt: string;
    vyper: any;
    dependencies: any;
    assertions_revert: boolean;
    legacy_assertions: boolean;
};

export type Deployment = {
    bytecode: string;
    address: `0x${string}`;
    abi: ethers.InterfaceAbi;
    data: string;
    artifact_path?: string;
    artifact_full_path?: string;
    standardJsonInput?: any;
    args_data?: string;
    tx_hash?: string;
    args: string[] | null;
};

export type DeploymentWithFileInfo = Deployment & {
    name?: string;
    path?: string;
};

export type DeploymentArtifact = DeploymentWithFileInfo & {
    compiler: string;
};

export type Artifact = {
    abi: ethers.InterfaceAbi;
    methodIdentifiers: {
        [key: string]: string;
    };
    metadata: {
        compiler: {
            version: string;
            settings: {
                evmVersion: string;
                optimizer: {
                    enabled: boolean;
                    runs: number;
                };
            };
        };
        settings: {
            optimizer: {
                enabled: boolean;
                runs: number;
            };
            compilationTarget: {
                [key: string]: string;
            };
        };
    };
};

export type Task = {
    name: string;
    description: string;
    task: (tooling: Tooling) => void;
};

export type TaskArg = string | boolean | undefined;
export type TaskArgValue = string | boolean | string[];

export type TaskArgsOption = {
    type: "string" | "boolean";
    required?: boolean;
    description?: string;
    default?: TaskArgValue;
    choices?: string[];
    transform?: (value: TaskArgValue) => TaskArgValue;
};

export type TaskArgsOptions = {
    [key: string]: TaskArgsOption;
};

export type TaskMeta = {
    name: string;
    description: string;
    options?: TaskArgsOptions;
    positionals?: {
        name: string;
        description?: string;
        required?: boolean;
    };
    requiresDeployerWallet?: boolean;
};

export type TaskArgs = {[key: string]: TaskArgValue};

export type TaskFunction = (taskArgs: TaskArgs, tooling: Tooling) => Promise<void>;

export enum AddressScopeType {
    DEFAULT = "default",
    OVERRIDDEN = "overridden",
    SPECIFIC = "specific",
}

export type BipsPercent = {
    bips: number;
    percent: number;
};

export type NamedAddress = {
    name?: string;
    address: `0x${string}`;
};

export type ERC20Meta = {
    name: string;
    symbol: string;
    decimals: number;
};

export enum CollateralType {
    ERC20 = "ERC20",
    ERC4626 = "ERC4626",
    UNISWAPV3_LP = "UNISWAPV3_LP",
}
