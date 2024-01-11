const fs = require('fs');
const { calculateChecksum } = require("../utils/gnosis");
const { utils } = require("ethers");
const { precrimeDeploymentNamePerNetwork, tokenDeploymentNamePerNetwork } = require('../utils/lz');

const CONFIG_TYPE_INBOUND_PROOF_LIBRARY_VERSION = 1;
const CONFIG_TYPE_INBOUND_BLOCK_CONFIRMATIONS = 2;
const CONFIG_TYPE_RELAYER = 3;
const CONFIG_TYPE_OUTBOUND_PROOF_TYPE = 4;
const CONFIG_TYPE_OUTBOUND_BLOCK_CONFIRMATIONS = 5;
const CONFIG_TYPE_ORACLE = 6;

// https://layerzero.gitbook.io/docs/evm-guides/ua-custom-configuration#set-inbound-proof-library
// 1: MPT
// 2: Feather Proof
const PROOF_LIBRARY_VERSION = 2;

// https://layerzero.gitbook.io/docs/ecosystem/oracle/google-cloud-oracle
const UA_ORACLE_ADDRESS = "0xD56e4eAb23cb81f43168F9F45211Eb027b9aC7cc";

// Usage exemple for a new chain:
// yarn task lzGnosisConfigure --from mainnet --to base --set-remote-path --set-min-gas --set-precrime --set-ua-oracle
module.exports = async function (taskArgs, hre) {
    const { getContract, getChainIdByNetworkName, changeNetwork, ethers } = hre;
    const foundry = hre.userConfig.foundry;

    const allNetworks = Object.keys(hre.config.networks).filter(network => network.mimLzSupported);
    const setUAOracle = taskArgs.setOracle;

    // Change these to the networks you want to generate the batch for
    const fromNetworks = (taskArgs.from === "all") ? hre.getAllNetworksLzMimSupported() : taskArgs.from.split(",");
    const toNetworks = (taskArgs.to === "all") ? hre.getAllNetworksLzMimSupported() : taskArgs.to.split(",");

    const setMinGas = taskArgs.setMinGas;
    const setRemotePath = taskArgs.setRemotePath;
    const setPrecrime = taskArgs.setPrecrime;
    const closeRemotePath = taskArgs.closeRemotePath;
    const setInputOutputLibraryVersion = taskArgs.setInputOutputLibraryVersion;

    if (!setMinGas && !setRemotePath && !setPrecrime && !closeRemotePath && !setUAOracle && !setInputOutputLibraryVersion) {
        console.log("Nothing to do, specify at least one of the following flags: --set-min-gas, --set-remote-path, --set-precrime, --close-remote-path, --set-ua-oracle, --set-input-output-library-version");
        process.exit(0);
    }


    if (closeRemotePath && setRemotePath) {
        console.log("Cannot set remote path and close remote path at the same time");
        process.exit(1);
    }

    const defaultBatch = Object.freeze({
        version: "1.0",
        chainId: "",
        createdAt: 0,
        meta: {},
        transactions: [

        ]
    });

    const defaultSetUAConfig = Object.freeze({
        to: "",
        value: "0",
        data: null,
        contractMethod: {
            inputs: [
                {
                    name: "_version",
                    type: "uint16",
                    internalType: "uint16"
                },
                {
                    name: "_chainId",
                    type: "uint16",
                    internalType: "uint16"
                },
                {
                    name: "_configType",
                    type: "uint256",
                    internalType: "uint256"
                },
                {
                    name: "_config",
                    type: "bytes",
                    internalType: "bytes"
                }
            ],
            name: "setConfig",
            payable: false
        },
        contractInputsValues: {
            _version: "",
            _chainId: "",
            _configType: "",
            _config: ""
        }
    });

    const defaultSetMinGasTx = Object.freeze({
        to: "",
        value: "0",
        data: null,
        contractMethod: {
            inputs: [
                {
                    internalType: "uint16",
                    name: "_dstChainId",
                    type: "uint16"
                },
                {
                    internalType: "uint16",
                    name: "_packetType",
                    type: "uint16"
                },
                {
                    internalType: "uint256",
                    name: "_minGas",
                    type: "uint256"
                }
            ],
            name: "setMinDstGas",
            payable: false
        },
        contractInputsValues: {
            _dstChainId: "",
            _packetType: "",
            _minGas: ""
        }

    });

    const defaultSetTrustedRemoteTx = Object.freeze({
        to: "",
        value: "0",
        data: null,
        contractMethod: {
            inputs: [
                {
                    internalType: "uint16",
                    name: "_remoteChainId",
                    type: "uint16"
                },
                {
                    internalType: "bytes",
                    name: "_path",
                    type: "bytes"
                }
            ],
            name: "setTrustedRemote",
            payable: false
        },
        contractInputsValues: {
            _remoteChainId: "",
            _path: ""
        }
    });

    const defaultSetPrecrime = Object.freeze({
        to: "",
        value: "0",
        data: null,
        contractMethod: {
            inputs: [
                {
                    internalType: "address",
                    name: "_precrime",
                    type: "address"
                }
            ],
            name: "setPrecrime",
            payable: false
        },
        contractInputsValues: {
            _precrime: ""
        }
    });

    const defaultSetRemotePrecrimeAddresses = Object.freeze({
        to: "",
        value: "0",
        data: null,
        contractMethod: {
            inputs: [
                {
                    internalType: "uint16[]",
                    name: "_remoteChainIds",
                    type: "uint16[]"
                },
                {
                    internalType: "bytes32[]",
                    name: "_remotePrecrimeAddresses",
                    type: "bytes32[]"
                }
            ],
            name: "setRemotePrecrimeAddresses",
            payable: false
        },
        contractInputsValues: {
            _remoteChainIds: "[1,2,3]",
            _remotePrecrimeAddresses: "[\"0x\",\"0x\"]"
        }
    });

    for (const srcNetwork of fromNetworks) {
        await changeNetwork(srcNetwork);
        const fromChainId = getChainIdByNetworkName(srcNetwork);
        const fromTokenContract = await getContract(tokenDeploymentNamePerNetwork[srcNetwork], fromChainId);

        console.log(`[${srcNetwork}] Generating tx batch...`);

        const batch = JSON.parse(JSON.stringify(defaultBatch));
        batch.chainId = fromChainId.toString();

        const { addresses } = require(`../../config/${srcNetwork}.json`);

        let endpointAddress = addresses.find(a => a.key === "LZendpoint");
        if (!endpointAddress) {
            console.log(`No LZendpoint address found for ${network}`);
            process.exit(1);
        }

        endpointAddress = endpointAddress.value;
        const endpoint = await getContractAt("ILzEndpoint", endpointAddress);
        const sendVersion = await endpoint.getSendVersion(fromTokenContract.address);

        for (const toNetwork of toNetworks) {
            if (toNetwork === srcNetwork) continue;

            await changeNetwork(toNetwork);
            const toChainId = getChainIdByNetworkName(toNetwork);
            const toTokenContract = await getContract(tokenDeploymentNamePerNetwork[toNetwork], toChainId);

            // sendFrom
            if (setMinGas) {
                console.log(` -> ${toNetwork}, packetType: 0, minGas: 100000`);
                let tx = JSON.parse(JSON.stringify(defaultSetMinGasTx));
                tx.to = fromTokenContract.address;
                tx.contractInputsValues._dstChainId = getLzChainIdByNetworkName(toNetwork).toString();
                tx.contractInputsValues._packetType = "0";
                tx.contractInputsValues._minGas = "100000";
                batch.transactions.push(tx);

                // sendFromAndCall
                console.log(` -> ${toNetwork}, packetType: 1, minGas: 200000`);
                tx = JSON.parse(JSON.stringify(defaultSetMinGasTx));
                tx.to = fromTokenContract.address;
                tx.contractInputsValues._dstChainId = getLzChainIdByNetworkName(toNetwork).toString();
                tx.contractInputsValues._packetType = "1";
                tx.contractInputsValues._minGas = "200000";
                batch.transactions.push(tx);
            }

            if (setRemotePath || closeRemotePath) {
                let remoteAndLocal = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";

                if (!closeRemotePath) {
                    remoteAndLocal = hre.ethers.utils.solidityPack(
                        ['address', 'address'],
                        [toTokenContract.address, fromTokenContract.address]
                    )
                }

                // 40 bytes + 0x
                if (remoteAndLocal.toString().length !== 80 + 2) {
                    console.log(`[${srcNetwork}] Invalid remoteAndLocal address: ${remoteAndLocal.toString()}`);
                    process.exit(1);
                }

                console.log(` -> ${toNetwork}, remoteAndLocal: ${remoteAndLocal.toString()}`);
                tx = JSON.parse(JSON.stringify(defaultSetTrustedRemoteTx));
                tx.to = fromTokenContract.address;
                tx.contractInputsValues._remoteChainId = getLzChainIdByNetworkName(toNetwork).toString();
                tx.contractInputsValues._path = remoteAndLocal.toString();
                batch.transactions.push(tx);
            }

            if (setUAOracle) {
                console.log(` -> ${toNetwork}, set UA oracle: ${UA_ORACLE_ADDRESS}`);
                let tx = JSON.parse(JSON.stringify(defaultSetUAConfig));
                tx.to = fromTokenContract.address;
                tx.contractInputsValues._version = sendVersion.toString();
                tx.contractInputsValues._chainId = getLzChainIdByNetworkName(toNetwork).toString();
                tx.contractInputsValues._configType = CONFIG_TYPE_ORACLE.toString();
                tx.contractInputsValues._config = utils.defaultAbiCoder.encode(["address"], [UA_ORACLE_ADDRESS]);
                batch.transactions.push(tx);
            }

            if(setInputOutputLibraryVersion) {
                console.log(` -> ${toNetwork}, set input output library version: ${PROOF_LIBRARY_VERSION}`);
                let tx = JSON.parse(JSON.stringify(defaultSetUAConfig));
                tx.to = fromTokenContract.address;
                tx.contractInputsValues._version = sendVersion.toString();
                tx.contractInputsValues._chainId = getLzChainIdByNetworkName(toNetwork).toString();
                tx.contractInputsValues._configType = CONFIG_TYPE_INBOUND_PROOF_LIBRARY_VERSION.toString();
                tx.contractInputsValues._config = utils.defaultAbiCoder.encode(["uint16"], [PROOF_LIBRARY_VERSION]);
                batch.transactions.push(tx);

                tx = JSON.parse(JSON.stringify(defaultSetUAConfig));
                tx.to = fromTokenContract.address;
                tx.contractInputsValues._version = sendVersion.toString();
                tx.contractInputsValues._chainId = getLzChainIdByNetworkName(toNetwork).toString();
                tx.contractInputsValues._configType = CONFIG_TYPE_OUTBOUND_PROOF_TYPE.toString();
                tx.contractInputsValues._config = utils.defaultAbiCoder.encode(["uint16"], [PROOF_LIBRARY_VERSION]);
                batch.transactions.push(tx);
            }
        }

        if (setPrecrime) {
            const precrimeContract = await getContract(precrimeDeploymentNamePerNetwork[srcNetwork], fromChainId);

            console.log(` -> ${srcNetwork}, precrime: ${precrimeContract.address.toString()}`);
            tx = JSON.parse(JSON.stringify(defaultSetPrecrime));
            tx.to = fromTokenContract.address;
            tx.contractInputsValues._precrime = precrimeContract.address.toString();
            batch.transactions.push(tx);

            let remoteChainIDs = [];
            let remotePrecrimeAddresses = [];

            for (const targetNetwork of Object.keys(precrimeDeploymentNamePerNetwork)) {
                if (targetNetwork === srcNetwork) continue;

                console.log(`[${srcNetwork}] Adding Precrime for ${precrimeDeploymentNamePerNetwork[targetNetwork]}`);
                const remoteChainId = hre.getNetworkConfigByName(targetNetwork).chainId;
                const remoteContractInstance = await getContract(precrimeDeploymentNamePerNetwork[targetNetwork], remoteChainId);

                const bytes32address = utils.defaultAbiCoder.encode(["address"], [remoteContractInstance.address])
                remoteChainIDs.push(getLzChainIdByNetworkName(targetNetwork));
                remotePrecrimeAddresses.push(bytes32address)
            }

            console.log(` -> ${srcNetwork}, set precrime remote addresses: ${precrimeContract.address.toString()}`);
            tx = JSON.parse(JSON.stringify(defaultSetRemotePrecrimeAddresses));
            tx.to = precrimeContract.address;
            tx.contractInputsValues._remoteChainIds = JSON.stringify(remoteChainIDs);
            tx.contractInputsValues._remotePrecrimeAddresses = JSON.stringify(remotePrecrimeAddresses);
            batch.transactions.push(tx);
        }

        batch.meta.checksum = calculateChecksum(hre.ethers, batch);
        content = JSON.stringify(batch, null, 4);
        fs.writeFileSync(`${hre.config.paths.root}/${foundry.out}/${srcNetwork}-batch.json`, content, 'utf8');
    }
}