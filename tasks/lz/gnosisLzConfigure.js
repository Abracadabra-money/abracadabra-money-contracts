const fs = require('fs');
const CHAIN_ID = require("./chainIds.json")
const { calculateChecksum } = require("../utils/gnosis");

module.exports = async function (taskArgs, hre) {
    const { getContract, getChainIdByNetworkName, changeNetwork } = hre;
    const foundry = hre.userConfig.foundry;

    const setRemotePath = true;
    const setMinGas = false;
    
    // Change these to the networks you want to generate the batch for
    const fromNetworks = ["optimism", "arbitrum", "moonriver", "avalanche", "mainnet", "bsc", "polygon", "fantom"];
    const toNetworks = ["kava"];

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

    for (const fromNetwork of fromNetworks) {
        await changeNetwork(fromNetwork);
        const fromChainId = getChainIdByNetworkName(fromNetwork);
        const fromTokenContract = await getContract(tokenDeploymentNamePerNetwork[fromNetwork], fromChainId);

        console.log(`[${fromNetwork}] Generating tx batch...`);

        const batch = JSON.parse(JSON.stringify(defaultBatch));
        batch.chainId = fromChainId.toString();

        for (const toNetwork of toNetworks) {
            if (toNetwork === fromNetwork) continue;

            await changeNetwork(toNetwork);
            const toChainId = getChainIdByNetworkName(toNetwork);
            const toTokenContract = await getContract(tokenDeploymentNamePerNetwork[toNetwork], toChainId);

            // sendFrom
            if (setMinGas) {
                let tx = JSON.parse(JSON.stringify(defaultSetMinGasTx));
                tx.to = fromTokenContract.address;
                tx.contractInputsValues._dstChainId = CHAIN_ID[toNetwork].toString();
                tx.contractInputsValues._packetType = "0";
                tx.contractInputsValues._minGas = "100000";
                batch.transactions.push(tx);

                // sendFromAndCall
                tx = JSON.parse(JSON.stringify(defaultSetMinGasTx));
                tx.to = fromTokenContract.address;
                tx.contractInputsValues._dstChainId = CHAIN_ID[toNetwork].toString();
                tx.contractInputsValues._packetType = "1";
                tx.contractInputsValues._minGas = "200000";
                batch.transactions.push(tx);
            }

            if (setRemotePath) {
                // setTrustedRemote
                let remoteAndLocal = hre.ethers.utils.solidityPack(
                    ['address', 'address'],
                    [toTokenContract.address, fromTokenContract.address]
                )

                // 40 bytes + 0x
                if (remoteAndLocal.toString().length !== 80 + 2) {
                    console.log(`[${fromNetwork}] Invalid remoteAndLocal address: ${remoteAndLocal.toString()}`);
                    process.exit(1);
                }

                tx = JSON.parse(JSON.stringify(defaultSetTrustedRemoteTx));
                tx.to = fromTokenContract.address;
                tx.contractInputsValues._remoteChainId = CHAIN_ID[toNetwork].toString();
                tx.contractInputsValues._path = remoteAndLocal.toString();
                batch.transactions.push(tx);
            }
        }

        batch.meta.checksum = calculateChecksum(hre.ethers, batch);
        content = JSON.stringify(batch, null, 4);
        fs.writeFileSync(`${hre.config.paths.root}/${foundry.out}/${fromNetwork}-batch.json`, content, 'utf8');
    }
}