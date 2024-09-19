import {Table} from "console-table-printer";
import {BigNumber} from "ethers";
import type {AddressEntry, NetworkName} from "../../types";
import {WAD} from "./constants";
import type {Tooling} from "../../tooling";

export type CauldronConfigSection = {
    [key: string]: CauldronConfigEntry;
};

export type CauldronStatus = "active" | "deprecated" | "removed";

export type CauldronConfigEntry = AddressEntry & {
    creationBlock: number;
    status: CauldronStatus;
    version: number;
};

export type CauldronOwnerInfo = {
    address: `0x${string}`;
    treasury: string;
    registry: string;
    owner: string;
};

export type CauldronInformation = {
    cauldronAddress: `0x${string}`;
    network: NetworkName;
    cauldronName: string;
    feesEarned: number | undefined;
    interest: number | undefined;
    liq_multiplier: number | undefined;
    collateralization: number | undefined;
    opening: number | undefined;
    borrow: number;
    bentoBox: any;
    mim: any;
    collateralName: string;
    collateralAmount: number;
    oracle: any;
    oracleData: string;
    peekSpot: number;
    decimals: number;
    spotPrice: number;
    exchangeRate: number;
    currentPrice: number;
    peekPrice: number;
    collateralValue: number;
    ltv: number;
    mimAmount: number;
    masterContract: `0x${string}`;
    masterContractOwner: `0x${string}`;
    feeTo: `0x${string}`;
    cauldronOwnerInfo: CauldronOwnerInfo | undefined;
};

export type MasterContractInfo = {
    address: `0x${string}`;
    owner: `0x${string}`;
    feeTo: `0x${string}`;
};

export const getCauldronByName = (tooling: Tooling, name: string): CauldronConfigEntry => {
    return tooling.getNetworkConfigByName(tooling.network.name).addresses?.cauldrons[name] as CauldronConfigEntry;
};

export const printCauldronInformation = (
    tooling: Tooling,
    cauldron: CauldronInformation,
    extra?: [row: {info: string; value: string}, params: {color: string}][]
) => {
    const p = new Table({
        columns: [
            {name: "info", alignment: "right", color: "cyan"},
            {name: "value", alignment: "left"},
        ],
    });

    const defaultValColors = {color: "green"};

    p.addRow({info: "Cauldron", value: cauldron.cauldronName}, defaultValColors);
    p.addRow({info: "Address", value: cauldron.cauldronAddress}, defaultValColors);
    p.addRow({info: "", value: ""}, defaultValColors);

    if (cauldron.interest) {
        p.addRow({info: "Interet", value: `${cauldron.interest.toFixed(2)} %`}, defaultValColors);
    }

    if (cauldron.collateralization) {
        p.addRow({info: "Collateralization", value: `${cauldron.collateralization.toFixed(2)} %`}, defaultValColors);
        p.addRow({info: "Opening fee", value: `${cauldron.opening?.toFixed(2)} %`}, defaultValColors);
        p.addRow({info: "Liquidation Multiplier", value: `${cauldron.liq_multiplier?.toFixed(2)} %`}, defaultValColors);
        p.addRow({info: "", value: ""}, defaultValColors);
    }

    p.addRow({info: "Available to be borrowed", value: `${cauldron.mimAmount.toLocaleString("us")} MIM`}, defaultValColors);
    p.addRow({info: "Total Borrowed", value: `${cauldron.borrow.toLocaleString("us")} MIM`}, defaultValColors);
    p.addRow({info: `Collateral Amount`, value: `${cauldron.collateralAmount.toLocaleString("us")}`}, defaultValColors);
    p.addRow({info: `Collateral Value`, value: `$${cauldron.collateralValue.toLocaleString("us")}`}, defaultValColors);
    p.addRow({info: `Collateral Price`, value: `$${cauldron.spotPrice.toLocaleString("us")}`}, defaultValColors);
    p.addRow({info: "LTV", value: `${cauldron.ltv.toFixed(2)} %`}, defaultValColors);

    p.addRow({info: "", value: ""}, defaultValColors);

    p.addRow({info: "MasterContract", value: cauldron.masterContract}, defaultValColors);
    p.addRow({info: "Owner", value: tooling.getLabeledAddress(cauldron.network, cauldron.masterContractOwner)}, defaultValColors);

    if (cauldron.feesEarned) {
        p.addRow({info: "", value: ""});
        p.addRow({info: "Fee Earned", value: `${cauldron.feesEarned.toLocaleString()} MIM`}, defaultValColors);
    }

    if (extra) {
        p.addRow({info: "", value: ""});

        for (const [row, params] of extra) {
            p.addRow(row, params);
        }
    }

    p.printTable();
};

export const getCauldronInformation = async (tooling: Tooling, cauldronName: string) => {
    let cauldronConfig = getCauldronByName(tooling, cauldronName);

    if (!cauldronConfig) {
        console.log(`Cauldron ${cauldronName} not found`);
        process.exit(1);
    }

    return getCauldronInformationUsingConfig(tooling, cauldronConfig);
};

export const getCauldronInformationUsingConfig = async (
    tooling: Tooling,
    cauldronConfig: CauldronConfigEntry
): Promise<CauldronInformation> => {
    const cauldron = await tooling.getContractAt("ICauldronV2", cauldronConfig.value);
    const bentoBox = await tooling.getContractAt("IBentoBoxV1", await cauldron.bentoBox());
    const mim = await tooling.getContractAt("IStrictERC20", await cauldron.magicInternetMoney());
    const collateral = await tooling.getContractAt("IStrictERC20", await cauldron.collateral());
    const oracle = await tooling.getContractAt("IOracle", await cauldron.oracle());
    const oracleData = await cauldron.oracleData();

    let peekSpot: number;
    let peekPrice: number;
    let decimals: number;
    let collateralName: string;

    try {
        peekSpot = parseFloat(await oracle.peekSpot(oracleData));
        peekPrice = parseFloat((await oracle.peek(oracleData))[1].toString());
        decimals = parseFloat(
            BigNumber.from(10)
                .pow(await collateral.decimals())
                .toString()
        );
    } catch (e) {
        peekSpot = 0;
        peekPrice = 0;
        decimals = 0;
    }

    try {
        collateralName = await collateral.name();
    } catch (e) {
        collateralName = "unknown";
    }

    let accrueInfo;
    let feesEarned;
    let interest;
    let liq_multiplier;
    let collateralization;
    let opening;

    if (cauldronConfig.version > 1) {
        accrueInfo = await cauldron.accrueInfo();
        feesEarned = accrueInfo[1] / 1e18;
        interest = (accrueInfo[2] * (365.25 * 3600 * 24)) / 1e16;
        liq_multiplier = (await cauldron.LIQUIDATION_MULTIPLIER()) / 1000 - 100;
        collateralization = (await cauldron.COLLATERIZATION_RATE()) / 1000;
        opening = (await cauldron.BORROW_OPENING_FEE()) / 1000;
    }

    const borrowRaw = await cauldron.totalBorrow();
    const borrow = borrowRaw[0].div(WAD).toNumber();

    const collateralShareRaw = await cauldron.totalCollateralShare();
    const collateralAmountRaw = await bentoBox.toAmount(collateral.address, collateralShareRaw, false);
    const collateralAmount = parseFloat(collateralAmountRaw.toString()) / decimals;

    const spotPrice = decimals / peekSpot;
    const exchangeRate = parseFloat((await cauldron.exchangeRate()).toString());
    const currentPrice = exchangeRate > 0 ? decimals / exchangeRate : 0;
    const collateralValue = collateralAmount * spotPrice;
    const ltv = collateralValue > 0 ? borrow / collateralValue : 0;

    const mimBalanceRaw = await bentoBox.balanceOf(mim.address, cauldron.address);
    const mimAmountRaw = await bentoBox.toAmount(mim.address, mimBalanceRaw, false);
    const mimAmount = mimAmountRaw.div(WAD).toNumber();

    const masterContract = await cauldron.masterContract();
    const masterContractOwner = await (await tooling.getContractAt("BoringOwnable", masterContract)).owner();
    const feeTo = await (await tooling.getContractAt("ICauldronV2", masterContract)).feeTo();

    // check if owner is a cauldron owner contract
    const cauldronOwner = await tooling.getContractAt("CauldronOwner", masterContractOwner);
    let cauldronOwnerInfo: CauldronOwnerInfo | undefined;

    try {
        cauldronOwnerInfo = {
            address: masterContractOwner,
            treasury: await cauldronOwner.treasury(),
            registry: await cauldronOwner.registry(),
            owner: await cauldronOwner.owner(),
        };
    } catch (e) {}

    return {
        cauldronAddress: cauldron.address as `0x${string}`,
        network: tooling.network.name,
        cauldronName: cauldronConfig.key,
        feesEarned,
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
        mimAmount,
        masterContract,
        masterContractOwner,
        feeTo,
        cauldronOwnerInfo,
    };
};
