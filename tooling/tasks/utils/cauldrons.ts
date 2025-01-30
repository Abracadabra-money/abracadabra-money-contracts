import {Table} from "console-table-printer";
import {formatUnits} from "ethers";
import type {AddressEntry, NetworkName} from "../../types";
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
    collateralAddress: `0x${string}`;
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
    box: any;
};

export const getCauldronByName = (tooling: Tooling, name: string): CauldronConfigEntry => {
    return tooling.getNetworkConfigByName(tooling.network.name).addresses?.cauldrons[name] as CauldronConfigEntry;
};

export const printCauldronInformation = async (
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
    p.addRow({info: "Collateral", value: tooling.getLabeledAddress(cauldron.network, cauldron.collateralAddress)}, defaultValColors);
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
    p.addRow({info: "Box", value: tooling.getLabeledAddress(cauldron.network, (await cauldron.bentoBox.getAddress()).toString())}, defaultValColors);

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
            (10n ** BigInt(await collateral.decimals())).toString()
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
        feesEarned = parseFloat(formatUnits(accrueInfo[1], 18));
        interest = (parseFloat(accrueInfo[2].toString()) * (365.25 * 3600 * 24)) / 1e16;
        liq_multiplier = (await cauldron.LIQUIDATION_MULTIPLIER()) / 1000n - 100n;
        collateralization = (await cauldron.COLLATERIZATION_RATE()) / 1000n;
        opening = (await cauldron.BORROW_OPENING_FEE()) / 1000n;
    }

    const borrowRaw = await cauldron.totalBorrow();
    const borrow = parseFloat(formatUnits(borrowRaw[0], 18));

    const collateralShareRaw = await cauldron.totalCollateralShare();
    const collateralAmountRaw = await bentoBox.toAmount(await collateral.getAddress(), collateralShareRaw, false);
    const collateralAmount = parseFloat(formatUnits(collateralAmountRaw, await collateral.decimals()));

    const spotPrice = decimals / peekSpot;
    const exchangeRate = parseFloat((await cauldron.exchangeRate()).toString());
    const currentPrice = exchangeRate > 0 ? decimals / exchangeRate : 0;
    const collateralValue = collateralAmount * spotPrice;
    const ltv = collateralValue > 0 ? borrow / collateralValue : 0;

    const mimBalanceRaw = await bentoBox.balanceOf(await mim.getAddress(), await cauldron.getAddress());
    const mimAmountRaw = await bentoBox.toAmount(await mim.getAddress(), mimBalanceRaw, false);
    const mimAmount = parseFloat(formatUnits(mimAmountRaw, 18));

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
        cauldronAddress: await cauldron.getAddress() as `0x${string}`,
        collateralAddress: await collateral.getAddress() as `0x${string}`,
        network: tooling.network.name,
        cauldronName: cauldronConfig.key,
        feesEarned,
        interest,
        liq_multiplier: liq_multiplier !== undefined ? Number(liq_multiplier) : undefined,
        collateralization: collateralization !== undefined ? Number(collateralization) : undefined,
        opening: opening !== undefined ? Number(opening) : undefined,
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
