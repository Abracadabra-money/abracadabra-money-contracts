import { Table } from 'console-table-printer';
import { BigNumber } from 'ethers';
import type { AddressEntry, Tooling } from '../../types';
import { WAD } from './constants';

export type CauldronConfigSection = {
    [key: string]: CauldronConfigEntry;
}

export type CauldronConfigEntry = AddressEntry & {
    creationBlock: number;
    deprecated: boolean;
    version: number;
};

export type CauldronInformation = {
    network: string;
    cauldronName: string;
    interest: number;
    liq_multiplier: number;
    collateralization: number;
    opening: number;
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
    masterContractOwner: string | `0x${string}`;
};

export const getCauldronByName = (tooling: Tooling, name: string): CauldronConfigEntry => {
    return tooling.getNetworkConfigByName(tooling.network.name).addresses?.cauldrons[name] as CauldronConfigEntry;
};

export const printCauldronInformation = (
    tooling: Tooling,
    cauldron: CauldronInformation,
    extra?: [row: { info: string; value: string }, params: { color: string }][]
) => {
    const p = new Table({
        columns: [
            { name: 'info', alignment: 'right', color: 'cyan' },
            { name: 'value', alignment: 'left' },
        ],
    });

    const defaultValColors = { color: 'green' };

    let masterContractLabelAndAddress = cauldron.masterContractOwner;

    const label = tooling.getLabelByAddress(cauldron.network, cauldron.masterContractOwner as `0x${string}`);
    if (label) {
        masterContractLabelAndAddress = `${masterContractLabelAndAddress} (${label})`;
    }

    p.addRow({ info: 'Cauldron', value: cauldron.cauldronName }, defaultValColors);
    p.addRow({ info: '', value: '' }, defaultValColors);

    p.addRow({ info: 'Interest', value: `${cauldron.interest.toFixed(2)} %` }, defaultValColors);
    p.addRow({ info: 'Collateralization', value: `${cauldron.collateralization.toFixed(2)} %` }, defaultValColors);
    p.addRow({ info: 'Opening fee', value: `${cauldron.opening.toFixed(2)} %` }, defaultValColors);
    p.addRow({ info: 'Liquidation Multiplier', value: `${cauldron.liq_multiplier.toFixed(2)} %` }, defaultValColors);
    p.addRow({ info: '', value: '' }, defaultValColors);

    p.addRow({ info: 'Available to be borrowed', value: `${cauldron.mimAmount.toLocaleString('us')} MIM` }, defaultValColors);
    p.addRow({ info: 'Total Borrowed', value: `${cauldron.borrow.toLocaleString('us')} MIM` }, defaultValColors);
    p.addRow({ info: `Collateral Amount`, value: `${cauldron.collateralAmount.toLocaleString('us')}` }, defaultValColors);
    p.addRow({ info: `Collateral Value`, value: `$${cauldron.collateralValue.toLocaleString('us')}` }, defaultValColors);
    p.addRow({ info: `Collateral Price`, value: `$${cauldron.spotPrice.toLocaleString('us')}` }, defaultValColors);
    p.addRow({ info: 'LTV', value: `${cauldron.ltv.toFixed(2)} %` }, defaultValColors);

    p.addRow({ info: '', value: '' }, defaultValColors);

    p.addRow({ info: 'MasterContract', value: cauldron.masterContract }, defaultValColors);
    p.addRow({ info: 'Owner', value: masterContractLabelAndAddress }, defaultValColors);

    if (extra) {
        p.addRow({ info: '', value: '' });

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

    if (cauldronConfig.version! < 2) {
        console.log(`Cauldrons version prior to v2 are not supported`);
        process.exit(1);
    }

    return getCauldronInformationUsingConfig(tooling, cauldronConfig);
};

export const getCauldronInformationUsingConfig = async (tooling: Tooling, cauldronConfig: CauldronConfigEntry): Promise<CauldronInformation> => {
    const cauldron = await tooling.getContractAt('ICauldronV2', cauldronConfig.value);
    const bentoBox = await tooling.getContractAt('IBentoBoxV1', await cauldron.bentoBox());
    const mim = await tooling.getContractAt('IStrictERC20', await cauldron.magicInternetMoney());
    const collateral = await tooling.getContractAt('IStrictERC20', await cauldron.collateral());
    const oracle = await tooling.getContractAt('IOracle', await cauldron.oracle());
    const oracleData = await cauldron.oracleData();

    let peekSpot: number;
    let peekPrice: number;
    let decimals: number;
    let collateralName: string;

    try {
        peekSpot = parseFloat(await oracle.peekSpot(oracleData));
        peekPrice = parseFloat((await oracle.peek(oracleData))[1].toString());
        decimals = parseFloat(BigNumber.from(10).pow(await collateral.decimals()).toString());
    } catch (e) {
        peekSpot = 0;
        peekPrice = 0;
        decimals = 0;
    }

    try {
        collateralName = await collateral.name();
    } catch (e) {
        collateralName = 'unknown';
    }

    const accrueInfo = await cauldron.accrueInfo();
    const interest = (accrueInfo[2] * (365.25 * 3600 * 24)) / 1e16;
    const liq_multiplier = (await cauldron.LIQUIDATION_MULTIPLIER()) / 1000 - 100;
    const collateralization = (await cauldron.COLLATERIZATION_RATE()) / 1000;
    const opening = (await cauldron.BORROW_OPENING_FEE()) / 1000;

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
    const masterContractOwner = await (await tooling.getContractAt('BoringOwnable', masterContract)).owner();

    return {
        network: tooling.network.name,
        cauldronName: cauldronConfig.key,
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
    };
};