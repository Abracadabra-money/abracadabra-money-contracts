const fs = require('fs');
const { calculateChecksum } = require("../utils/gnosis");
const { minterDeploymentNamePerNetwork, tokenDeploymentNamePerNetwork } = require('../utils/lz');

module.exports = async function (taskArgs, hre) {
    const { getContract, getChainIdByNetworkName } = hre;
    const foundry = hre.userConfig.foundry;

    const networks = ["optimism", "arbitrum", "moonriver", "avalanche", "bsc", "polygon", "fantom"];

    const previousTokenDeploymentNamePerNetwork = {
        "bsc": "0xaB137bb12e93fEdB8B639771c4C4fE29aC138Ee6",
        "polygon": "0xF4B36812d1645dca9d562846E3aBf416D590349e",
        "fantom": "0xd3a238d0E0f47AaC26defd2AFCf03eA41DA263C7",
        "optimism": "0xA3Ba2164553D2f266863968641a9cA47525Cb11D",
        "arbitrum": "0xB94d2014735B96152ddf97825a816Fca26846e91",
        "avalanche": "0x56d924066bf9eF61caA26F8f1aeB451EA950e475",
        "moonriver": "0x15f57fbCB7A443aC6022e051a46cAE19491bC298",
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
                    internalType: "address",
                    name: "operator",
                    type: "address"
                },
                {
                    internalType: "bool",
                    name: "status",
                    type: "bool"
                }
            ],
            name: "setOperator",
            payable: false
        },
        contractInputsValues: {
            operator: "",
            status: ""
        }

    });

    for (const fromNetwork of networks) {
        const chainId = getChainIdByNetworkName(fromNetwork);
        const minterContract = await getContract(minterDeploymentNamePerNetwork[fromNetwork], chainId);
        const tokenContractAddress = (await getContract(tokenDeploymentNamePerNetwork[fromNetwork], chainId)).address;
        const prevTokenContractAddress = previousTokenDeploymentNamePerNetwork[fromNetwork];

        console.log(`[${fromNetwork}] Generating tx batch...`);

        const batch = JSON.parse(JSON.stringify(defaultBatch));
        batch.chainId = chainId.toString();

        // setOperator false to the previous token contract
        let tx = JSON.parse(JSON.stringify(defaultTx));
        tx.to = minterContract.address;
        tx.contractInputsValues.operator = prevTokenContractAddress.toString();
        tx.contractInputsValues.status = "false";;
        batch.transactions.push(tx);

        // setOperator true to the current token contract
        tx = JSON.parse(JSON.stringify(defaultTx));
        tx.to = minterContract.address;
        tx.contractInputsValues.operator = tokenContractAddress.toString();
        tx.contractInputsValues.status = "true";
        batch.transactions.push(tx);

        batch.meta.checksum = calculateChecksum(hre.ethers, batch);
        content = JSON.stringify(batch, null, 4);
        fs.writeFileSync(`${hre.config.paths.root}/${foundry.out}/${fromNetwork}-changeOperators-batch.json`, content, 'utf8');
    }
}