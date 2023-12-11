const { Table } = require("console-table-printer");
const { BigNumber } = require("ethers");

const WAD = BigNumber.from("1000000000000000000");

const _findByKey = (configSection, key) => configSection.find((a) => a.key === key);

const loadConfig = (networkName) => {
    return require(`${__dirname}/../../config/${networkName}.json`)
}

const getAddress = (config, name, defaultValue) => {
    const item = _findByKey(config.addresses, name);

    if (item === undefined) {
        if (defaultValue !== undefined) {
            return defaultValue;
        }

        console.log(`No address for '${name}' found`);
        process.exit(1);
    }

    return item.value;
}

const getCauldron = (config, name) => {
    const item = _findByKey(config.cauldrons, name);

    if (!item) {
        console.log(`Cauldron ${name} doesn't exist `);

        const cauldronsV1 = config.cauldrons.filter(cauldron => cauldron.version < 2);
        if (cauldronsV1.length > 0) {
            console.log("Unsupported cauldrons (version < 2):")
            for (const cauldron of cauldronsV1) {
                console.log(`- ${cauldron.key}`);
            }
            console.log("");

        }

        console.log("Available cauldrons:");
        config.cauldrons = config.cauldrons.filter(cauldron => cauldron.version >= 2);

        for (const cauldron of config.cauldrons) {
            console.log(`- ${cauldron.key}`);
        }


        process.exit(1);
    }

    return item;
}

const printCauldronInformation = (cauldron, extra) => {
    const p = new Table({
        columns: [
            { name: 'info', alignment: 'right', color: "cyan" },
            { name: 'value', alignment: 'left' }
        ],
    });

    const defaultValColors = { color: "green" };

    p.addRow({ info: "Cauldron", value: cauldron.cauldronName }, defaultValColors);
    p.addRow({ info: "", value: "" }, defaultValColors);

    p.addRow({ info: "Interest", value: `${cauldron.interest.toFixed(2)} %` }, defaultValColors);
    p.addRow({ info: "Collateralization", value: `${cauldron.collateralization.toFixed(2)} %` }, defaultValColors);
    p.addRow({ info: "Opening fee", value: `${cauldron.opening.toFixed(2)} %` }, defaultValColors);
    p.addRow({ info: "Liquidation Multiplier", value: `${cauldron.liq_multiplier.toFixed(2)} %` }, defaultValColors);
    p.addRow({ info: "", value: "" }, defaultValColors);

    p.addRow({ info: "Available to be borrowed", value: `${cauldron.mimAmount.toLocaleString("us")} MIM` }, defaultValColors);
    p.addRow({ info: "Total Borrowed", value: `${cauldron.borrow.toLocaleString("us")} MIM` }, defaultValColors);
    p.addRow({ info: `Collateral Amount`, value: `${cauldron.collateralAmount.toLocaleString("us")}` }, defaultValColors);
    p.addRow({ info: `Collateral Value`, value: `$${cauldron.collateralValue.toLocaleString("us")}` }, defaultValColors);
    p.addRow({ info: `Collateral Price`, value: `$${cauldron.spotPrice.toLocaleString("us")}` }, defaultValColors);
    p.addRow({ info: "LTV", value: `${cauldron.ltv.toFixed(2)} %` }, defaultValColors);

    if (extra) {
        p.addRow({ info: "", value: "" });

        for (const [row, params] of extra) {
            p.addRow(row, params);
        }
    }

    p.printTable();
}

const getCauldronInformation = async (hre, config, cauldronName) => {
    let cauldronConfig = getCauldron(config, cauldronName);

    if (cauldronConfig.version < 2) {
        console.log(`Cauldrons version prior to v2 are not supported`);
        process.exit(1);

    }
    const cauldron = await hre.getContractAt("ICauldronV2", cauldronConfig.value);
    const bentoBox = await hre.getContractAt("IBentoBoxV1", await cauldron.bentoBox());
    const mim = await hre.getContractAt("IStrictERC20", await cauldron.magicInternetMoney());
    const collateral = await hre.getContractAt("IStrictERC20", await cauldron.collateral());
    const oracle = await hre.getContractAt("IOracle", await cauldron.oracle());
    const oracleData = await cauldron.oracleData();
    const peekSpot = parseFloat(await oracle.peekSpot(oracleData));
    const peekPrice = parseFloat((await oracle.peek(oracleData))[1].toString());
    const decimals = parseFloat(BigNumber.from(10).pow(await collateral.decimals()).toString());
    const collateralName = await collateral.name();

    const accrueInfo = await cauldron.accrueInfo();
    const interest = accrueInfo[2] * (365.25 * 3600 * 24) / 1e16;
    const liq_multiplier = ((await cauldron.LIQUIDATION_MULTIPLIER()) / 1000) - 100;
    const collateralization = (await cauldron.COLLATERIZATION_RATE()) / 1000;
    const opening = (await cauldron.BORROW_OPENING_FEE()) / 1000;
    const borrow = parseInt((await cauldron.totalBorrow())[0] / WAD);
    const collateralAmount = parseInt(parseFloat((await bentoBox.toAmount(collateral.address, await cauldron.totalCollateralShare(), false)).toString()) / decimals);
    const spotPrice = decimals / peekSpot;
    const exchangeRate = parseFloat(await cauldron.exchangeRate().toString());
    const currentPrice = exchangeRate > 0 ? decimal / exchangeRate : 0;
    const collateralValue = collateralAmount * spotPrice;
    const ltv = collateralValue > 0 ? borrow / collateralValue : 0;
    const mimAmount = parseInt(await bentoBox.toAmount(mim.address, await bentoBox.balanceOf(mim.address, cauldron.address), false) / WAD);

    return {
        cauldronName,
        interest,
        liq_multiplier,
        collateralization,
        opening,
        borrow,
        bentoBox,
        mim,
        collateralName,
        collateralAmount,
        oracle,
        oracleData,
        peekSpot,
        decimals,
        spotPrice,
        exchangeRate,
        currentPrice,
        peekPrice,
        collateralValue,
        ltv,
        mimAmount
    }
};

module.exports = {
    getAddress,
    getCauldron,
    loadConfig,
    getCauldronInformation,
    printCauldronInformation,
    WAD
}