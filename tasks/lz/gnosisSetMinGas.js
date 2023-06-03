const fs = require('fs');
const CHAIN_ID = require("./chainIds.json")

const stringifyReplacer = (_, value) => (value === undefined ? null : value);

const serializeJSONObject = (json) => {
    if (Array.isArray(json)) {
        return `[${json.map((el) => serializeJSONObject(el)).join(',')}]`;
    }

    if (typeof json === 'object' && json !== null) {
        let acc = '';
        const keys = Object.keys(json).sort();
        acc += `{${JSON.stringify(keys, stringifyReplacer)}`;

        for (let i = 0; i < keys.length; i++) {
            acc += `${serializeJSONObject(json[keys[i]])},`;
        }

        return `${acc}}`;
    }

    return `${JSON.stringify(json, stringifyReplacer)}`;
};

const calculateChecksum = (ethers, batchFile) => {
    const serialized = serializeJSONObject({
        ...batchFile,
        meta: { ...batchFile.meta, name: null },
    });
    const sha = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(serialized));

    return sha || undefined;
};


module.exports = async function (taskArgs, hre) {
    const { getContract, getChainIdByNetworkName } = hre;
    const foundry = hre.userConfig.foundry;

    const networks = ["optimism", "arbitrum", "moonriver", "avalanche", "mainnet", "bsc", "polygon", "fantom"];

    const tokenDeploymentNamePerNetwork = {
        "mainnet": "Mainnet_ProxyOFTV2",
        "bsc": "BSC_IndirectOFTV2",
        "polygon": "Polygon_IndirectOFTV2",
        "fantom": "Fantom_IndirectOFTV2",
        "optimism": "Optimism_IndirectOFTV2",
        "arbitrum": "Arbitrum_IndirectOFTV2",
        "avalanche": "Avalanche_IndirectOFTV2",
        "moonriver": "Moonriver_IndirectOFTV2",
    };

    const defaultBatch = Object.freeze({
        version: "1.0",
        chainId: "",
        createdAt: 0,
        meta: {},
        transactions: [

        ]
    });

    const defaultTx = Object.freeze({
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

    for (const fromNetwork of networks) {
        const chainId = getChainIdByNetworkName(fromNetwork);
        const tokenContract = await getContract(tokenDeploymentNamePerNetwork[fromNetwork], chainId);

        console.log(`[${fromNetwork}] Generating tx batch...`);

        const batch = JSON.parse(JSON.stringify(defaultBatch));
        batch.chainId = chainId.toString();

        for (const toNetwork of networks) {
            if (toNetwork === fromNetwork) continue;

            // sendFrom
            let tx = JSON.parse(JSON.stringify(defaultTx));
            tx.to = tokenContract.address;
            tx.contractInputsValues._dstChainId = CHAIN_ID[toNetwork].toString();
            tx.contractInputsValues._packetType = "0";
            tx.contractInputsValues._minGas = "100000";
            batch.transactions.push(tx);

            // sendFromAndCall
            tx = JSON.parse(JSON.stringify(defaultTx));
            tx.to = tokenContract.address;
            tx.contractInputsValues._dstChainId = CHAIN_ID[toNetwork].toString();
            tx.contractInputsValues._packetType = "1";
            tx.contractInputsValues._minGas = "200000";
            batch.transactions.push(tx);
        }

        batch.meta.checksum = calculateChecksum(hre.ethers, batch);
        content = JSON.stringify(batch, null, 4);
        fs.writeFileSync(`${hre.config.paths.root}/${foundry.out}/${fromNetwork}-batch.json`, content, 'utf8');
    }
}