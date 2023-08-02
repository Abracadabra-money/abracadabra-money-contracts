const fs = require('fs');
const { calculateChecksum } = require("../utils/gnosis");
const { utils } = require("ethers")

// Usage exemple:
// yarn task lzGnosisConfigure --from mainnet --to base --set-remote-path --set-precrime
module.exports = async function (taskArgs, hre) {
    const { getContract, getChainIdByNetworkName, changeNetwork, ethers } = hre;
    const foundry = hre.userConfig.foundry;

    const allNetworks = Object.keys(hre.config.networks);

    // Change these to the networks you want to generate the batch for
    const fromNetworks = (taskArgs.from === "all") ? allNetworks : taskArgs.from.split(",");
    const toNetworks = (taskArgs.to === "all") ? allNetworks : taskArgs.to.split(",");

    const setMinGas = taskArgs.setMinGas;
    const setRemotePath = taskArgs.setRemotePath;
    const setPrecrime = taskArgs.setPrecrime;
    const closeRemotePath = taskArgs.closeRemotePath;

    if (!setMinGas && !setRemotePath && !setPrecrime && !closeRemotePath) {
        console.log("Nothing to do, specify at least one of the following flags: --set-min-gas, --set-remote-path, --set-precrime, --close-remote-path");
        process.exit(0);
    }

    if (closeRemotePath && setRemotePath) {
        console.log("Cannot set remote path and close remote path at the same time");
        process.exit(1);
    }

    const tokenDeploymentNamePerNetwork = {
        "mainnet": "Mainnet_ProxyOFTV2",
        "bsc": "BSC_IndirectOFTV2",
        "polygon": "Polygon_IndirectOFTV2",
        "fantom": "Fantom_IndirectOFTV2",
        "optimism": "Optimism_IndirectOFTV2",
        "arbitrum": "Arbitrum_IndirectOFTV2",
        "avalanche": "Avalanche_IndirectOFTV2",
        "moonriver": "Moonriver_IndirectOFTV2",
        "kava": "Kava_IndirectOFTV2",
        "base": "Base_IndirectOFTV2"
    };

    const precrimeDeploymentNamePerNetwork = {
        "mainnet": "Mainnet_Precrime",
        "bsc": "BSC_Precrime",
        "polygon": "Polygon_Precrime",
        "fantom": "Fantom_Precrime",
        "optimism": "Optimism_Precrime",
        "arbitrum": "Arbitrum_Precrime",
        "avalanche": "Avalanche_Precrime",
        "moonriver": "Moonriver_Precrime",
        "kava": "Kava_Precrime",
        "base": "Base_Precrime"
    };

    const defaultBatch = Object.freeze({
        version: "1.0",
        chainId: "",
        createdAt: 0,
        meta: {},
        transactions: [

        ]
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