import fs from "fs";
import {utils, ethers} from "ethers";
import {calculateChecksum} from "../utils/gnosis";
import {
    CONFIG_TYPE_INBOUND_PROOF_LIBRARY_VERSION,
    CONFIG_TYPE_OUTBOUND_PROOF_TYPE,
    CONFIG_TYPE_ORACLE,
    PROOF_LIBRARY_VERSION,
    UA_ORACLE_ADDRESS,
    lz,
} from "../utils/lz";
import type {NetworkName, TaskArgs, TaskArgValue, TaskFunction, TaskMeta} from "../../types";
import type {Tooling} from "../../tooling";

export const meta: TaskMeta = {
    name: "lz/configure",
    description: "Configure LayerZero settings for multiple networks",
    options: {
        from: {
            type: "string",
            description: 'Source networks (comma-separated or "all")',
            required: true,
        },
        to: {
            type: "string",
            description: 'Target networks (comma-separated or "all")',
            required: true,
        },
        token: {
            type: "string",
            required: true,
            description: "token",
            choices: ["mim", "spell"],
            transform: (value: TaskArgValue) => (value as string).toUpperCase(),
        },
        setOracle: {
            type: "boolean",
            description: "Set UA oracle address",
        },
        setMinGas: {
            type: "boolean",
            description: "Set minimum gas",
        },
        setRemotePath: {
            type: "boolean",
            description: "Set remote path",
        },
        setPrecrime: {
            type: "boolean",
            description: "Set precrime address",
        },
        closeRemotePath: {
            type: "boolean",
            description: "Close remote path",
        },
        setInputOutputLibraryVersion: {
            type: "boolean",
            description: "Set input/output library version",
        },
    },
};

const defaultBatch = Object.freeze({
    version: "1.0",
    chainId: "",
    createdAt: 0,
    meta: {},
    transactions: [],
});

const defaultSetUAConfig = Object.freeze({
    to: "",
    value: "0",
    data: null,
    contractMethod: {
        inputs: [
            {name: "_version", type: "uint16", internalType: "uint16"},
            {name: "_chainId", type: "uint16", internalType: "uint16"},
            {name: "_configType", type: "uint256", internalType: "uint256"},
            {name: "_config", type: "bytes", internalType: "bytes"},
        ],
        name: "setConfig",
        payable: false,
    },
    contractInputsValues: {
        _version: "",
        _chainId: "",
        _configType: "",
        _config: "",
    },
});

const defaultSetMinGasTx = Object.freeze({
    to: "",
    value: "0",
    data: null,
    contractMethod: {
        inputs: [
            {internalType: "uint16", name: "_dstChainId", type: "uint16"},
            {internalType: "uint16", name: "_packetType", type: "uint16"},
            {internalType: "uint256", name: "_minGas", type: "uint256"},
        ],
        name: "setMinDstGas",
        payable: false,
    },
    contractInputsValues: {
        _dstChainId: "",
        _packetType: "",
        _minGas: "",
    },
});

const defaultSetTrustedRemoteTx = Object.freeze({
    to: "",
    value: "0",
    data: null,
    contractMethod: {
        inputs: [
            {internalType: "uint16", name: "_remoteChainId", type: "uint16"},
            {internalType: "bytes", name: "_path", type: "bytes"},
        ],
        name: "setTrustedRemote",
        payable: false,
    },
    contractInputsValues: {
        _remoteChainId: "",
        _path: "",
    },
});

const defaultSetPrecrime = Object.freeze({
    to: "",
    value: "0",
    data: null,
    contractMethod: {
        inputs: [{internalType: "address", name: "_precrime", type: "address"}],
        name: "setPrecrime",
        payable: false,
    },
    contractInputsValues: {
        _precrime: "",
    },
});

const defaultSetRemotePrecrimeAddresses = Object.freeze({
    to: "",
    value: "0",
    data: null,
    contractMethod: {
        inputs: [
            {internalType: "uint16[]", name: "_remoteChainIds", type: "uint16[]"},
            {internalType: "bytes32[]", name: "_remotePrecrimeAddresses", type: "bytes32[]"},
        ],
        name: "setRemotePrecrimeAddresses",
        payable: false,
    },
    contractInputsValues: {
        _remoteChainIds: "[1,2,3]",
        _remotePrecrimeAddresses: '["0x","0x"]',
    },
});

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    taskArgs.from = taskArgs.from as string;
    taskArgs.to = taskArgs.to as string;

    const tokenName = taskArgs.token as string;
    const setUAOracle = taskArgs.setOracle;
    const supportedNetworks = lz.getSupportedNetworks(tokenName);

    const fromNetworks = taskArgs.from === "all" ? supportedNetworks : (taskArgs.from.split(",") as NetworkName[]);
    const toNetworks = taskArgs.to === "all" ? supportedNetworks : (taskArgs.to.split(",") as NetworkName[]);

    const setMinGas = taskArgs.setMinGas;
    const setRemotePath = taskArgs.setRemotePath;
    const setPrecrime = taskArgs.setPrecrime;
    const closeRemotePath = taskArgs.closeRemotePath;
    const setInputOutputLibraryVersion = taskArgs.setInputOutputLibraryVersion;

    if (!setMinGas && !setRemotePath && !setPrecrime && !closeRemotePath && !setUAOracle && !setInputOutputLibraryVersion) {
        console.log(
            "Nothing to do, specify at least one of the following flags: --set-min-gas, --set-remote-path, --set-precrime, --close-remote-path, --set-ua-oracle, --set-input-output-library-version"
        );
        process.exit(0);
    }

    if (closeRemotePath && setRemotePath) {
        console.log("Cannot set remote path and close remote path at the same time");
        process.exit(1);
    }

    for (const srcNetwork of fromNetworks) {
        const sourceNetworkConfig = lz.getDeployementConfig(tooling, tokenName, srcNetwork);
        
        await tooling.changeNetwork(srcNetwork);
        const fromChainId = tooling.getChainIdByName(srcNetwork);
        const fromTokenContract = await tooling.getContract(sourceNetworkConfig.oft, fromChainId);

        console.log(`[${srcNetwork}] Generating tx batch...`);

        const batch = JSON.parse(JSON.stringify(defaultBatch));
        batch.chainId = fromChainId.toString();

        const endpointAddress = await tooling.getAddressByLabel(srcNetwork, "LZendpoint");
        const endpoint = await tooling.getContractAt("ILzEndpoint", endpointAddress as `0x${string}`);
        const sendVersion = await endpoint.getSendVersion(fromTokenContract.address);

        for (const toNetwork of toNetworks) {
            if (toNetwork === srcNetwork) continue;

            await tooling.changeNetwork(toNetwork);
            const toNetworkConfig = lz.getDeployementConfig(tooling, tokenName, toNetwork);
            const toChainId = tooling.getChainIdByName(toNetwork);
            const toTokenContract = await tooling.getContract(toNetworkConfig.oft, toChainId);

            if (setMinGas) {
                console.log(` -> ${toNetwork}, packetType: 0, minGas: 100000`);
                let tx = JSON.parse(JSON.stringify(defaultSetMinGasTx));
                tx.to = fromTokenContract.address;
                tx.contractInputsValues._dstChainId = tooling.getLzChainIdByName(toNetwork).toString();
                tx.contractInputsValues._packetType = "0";
                tx.contractInputsValues._minGas = "100000";
                batch.transactions.push(tx);

                console.log(` -> ${toNetwork}, packetType: 1, minGas: 200000`);
                tx = JSON.parse(JSON.stringify(defaultSetMinGasTx));
                tx.to = fromTokenContract.address;
                tx.contractInputsValues._dstChainId = tooling.getLzChainIdByName(toNetwork).toString();
                tx.contractInputsValues._packetType = "1";
                tx.contractInputsValues._minGas = "200000";
                batch.transactions.push(tx);
            }

            if (setRemotePath || closeRemotePath) {
                let remoteAndLocal = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";

                if (!closeRemotePath) {
                    remoteAndLocal = ethers.utils.solidityPack(
                        ["address", "address"],
                        [toTokenContract.address, fromTokenContract.address]
                    );
                }

                if (remoteAndLocal.length !== 80 + 2) {
                    console.log(`[${srcNetwork}] Invalid remoteAndLocal address: ${remoteAndLocal}`);
                    process.exit(1);
                }

                console.log(` -> ${toNetwork}, remoteAndLocal: ${remoteAndLocal}`);
                const tx = JSON.parse(JSON.stringify(defaultSetTrustedRemoteTx));
                tx.to = fromTokenContract.address;
                tx.contractInputsValues._remoteChainId = tooling.getLzChainIdByName(toNetwork).toString();
                tx.contractInputsValues._path = remoteAndLocal;
                batch.transactions.push(tx);
            }

            if (setUAOracle) {
                console.log(` -> ${toNetwork}, set UA oracle: ${UA_ORACLE_ADDRESS}`);
                const tx = JSON.parse(JSON.stringify(defaultSetUAConfig));
                tx.to = fromTokenContract.address;
                tx.contractInputsValues._version = sendVersion.toString();
                tx.contractInputsValues._chainId = tooling.getLzChainIdByName(toNetwork).toString();
                tx.contractInputsValues._configType = CONFIG_TYPE_ORACLE.toString();
                tx.contractInputsValues._config = utils.defaultAbiCoder.encode(["address"], [UA_ORACLE_ADDRESS]);
                batch.transactions.push(tx);
            }

            if (setInputOutputLibraryVersion) {
                console.log(` -> ${toNetwork}, set input output library version: ${PROOF_LIBRARY_VERSION}`);
                let tx = JSON.parse(JSON.stringify(defaultSetUAConfig));
                tx.to = fromTokenContract.address;
                tx.contractInputsValues._version = sendVersion.toString();
                tx.contractInputsValues._chainId = tooling.getLzChainIdByName(toNetwork).toString();
                tx.contractInputsValues._configType = CONFIG_TYPE_INBOUND_PROOF_LIBRARY_VERSION.toString();
                tx.contractInputsValues._config = utils.defaultAbiCoder.encode(["uint16"], [PROOF_LIBRARY_VERSION]);
                batch.transactions.push(tx);

                tx = JSON.parse(JSON.stringify(defaultSetUAConfig));
                tx.to = fromTokenContract.address;
                tx.contractInputsValues._version = sendVersion.toString();
                tx.contractInputsValues._chainId = tooling.getLzChainIdByName(toNetwork).toString();
                tx.contractInputsValues._configType = CONFIG_TYPE_OUTBOUND_PROOF_TYPE.toString();
                tx.contractInputsValues._config = utils.defaultAbiCoder.encode(["uint16"], [PROOF_LIBRARY_VERSION]);
                batch.transactions.push(tx);
            }
        }

        if (setPrecrime) {
            const precrimeContract = await tooling.getContract(sourceNetworkConfig.precrime, fromChainId);

            console.log(` -> ${srcNetwork}, precrime: ${precrimeContract.address}`);
            const tx = JSON.parse(JSON.stringify(defaultSetPrecrime));
            tx.to = fromTokenContract.address;
            tx.contractInputsValues._precrime = precrimeContract.address;
            batch.transactions.push(tx);

            let remoteChainIDs = [];
            let remotePrecrimeAddresses = [];

            for (const targetNetwork of Object.keys(supportedNetworks) as NetworkName[]) {
                if (targetNetwork === srcNetwork) continue;

                const targetNetworkConfig = lz.getDeployementConfig(tooling, tokenName, targetNetwork);

                console.log(`[${srcNetwork}] Adding Precrime for ${targetNetworkConfig.precrime}`);
                const remoteChainId = tooling.getNetworkConfigByName(targetNetwork).chainId;
                const remoteContractInstance = await tooling.getContract(targetNetworkConfig.precrime, remoteChainId);

                const bytes32address = utils.defaultAbiCoder.encode(["address"], [remoteContractInstance.address]);
                remoteChainIDs.push(tooling.getLzChainIdByName(targetNetwork));
                remotePrecrimeAddresses.push(bytes32address);
            }

            console.log(` -> ${srcNetwork}, set precrime remote addresses: ${precrimeContract.address}`);
            const txRemotePrecrime = JSON.parse(JSON.stringify(defaultSetRemotePrecrimeAddresses));
            txRemotePrecrime.to = precrimeContract.address;
            txRemotePrecrime.contractInputsValues._remoteChainIds = JSON.stringify(remoteChainIDs);
            txRemotePrecrime.contractInputsValues._remotePrecrimeAddresses = JSON.stringify(remotePrecrimeAddresses);
            batch.transactions.push(txRemotePrecrime);
        }

        batch.meta.checksum = calculateChecksum(batch);
        const content = JSON.stringify(batch, null, 4);
        const filename = `${tooling.config.projectRoot}/${tooling.config.foundry.out}/${srcNetwork}-batch.json`;
        fs.writeFileSync(filename, content, "utf8");
        console.log(`Transaction batch saved to ${filename}`);
    }
};
