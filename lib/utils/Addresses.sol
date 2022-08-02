// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Addresses {
    mapping(string => address) private v;

    constructor() {
        v["xMerlin"] = 0xfddfE525054efaAD204600d00CA86ADb1Cc2ea8a;

        v["mainnet.cauldronV3"] = 0x3E2a2BC69E5C22A8DA4056B413621D1820Eb493E;
        v["mainnet.cauldronV3Whitelisted"] = 0xe0d2007F6F2A71B90143D6667257d95643183F2b;
        v["mainnet.degenBox"] = 0xd96f48665a1410C0cd669A88898ecA36B9Fc2cce;
        v["mainnet.mim"] = 0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3;
        v["mainnet.spell"] = 0x090185f2135308BaD17527004364eBcC2D37e5F6;
        v["mainnet.usdc"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        v["mainnet.usdt"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        v["mainnet.stargate.stg"] = 0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6;
        v["mainnet.stargate.router"] = 0x8731d54E9D02c286767d56ac03e8037C07e01e98;
        v["mainnet.stargate,usdcPool"] = 0xdf0770dF86a8034b3EFEf0A1Bb3c889B8332FF56;
        v["mainnet.stargate.usdtPool"] = 0x38EA452219524Bb87e18dE1C24D3bB59510BD783;
        v["mainnet.curve.mim3Crv"] = 0x5a6A4D54456819380173272A5E8E9B9904BdF41B;
        v["mainnet.aggregators.zeroXExchangProxy"] = 0x5a6A4D54456819380173272A5E8E9B9904BdF41B;
    }

    function get(string calldata key) public view returns (address) {
        require(v[key] != address(0), string.concat("key not found: ", key));
        return v[key];
    }
}
