// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Vm.sol";
import "forge-std/console.sol";

contract Constants {
    mapping(string => address) private addressMap;
    mapping(string => bytes32) private pairCodeHash;

    string[] private addressKeys;

    constructor() {
        setAddress("xMerlin", 0xfddfE525054efaAD204600d00CA86ADb1Cc2ea8a);

        // Mainet
        setAddress("mainnet.cauldronV3", 0x3E2a2BC69E5C22A8DA4056B413621D1820Eb493E);
        setAddress("mainnet.cauldronV3Whitelisted", 0xe0d2007F6F2A71B90143D6667257d95643183F2b);
        setAddress("mainnet.degenBox", 0xd96f48665a1410C0cd669A88898ecA36B9Fc2cce);
        setAddress("mainnet.weth", 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        setAddress("mainnet.mim", 0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
        setAddress("mainnet.spell", 0x090185f2135308BaD17527004364eBcC2D37e5F6);
        setAddress("mainnet.usdc", 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        setAddress("mainnet.usdt", 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        setAddress("mainnet.stargate.stg", 0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6);
        setAddress("mainnet.stargate.router", 0x8731d54E9D02c286767d56ac03e8037C07e01e98);
        setAddress("mainnet.stargate,usdcPool", 0xdf0770dF86a8034b3EFEf0A1Bb3c889B8332FF56);
        setAddress("mainnet.stargate.usdtPool", 0x38EA452219524Bb87e18dE1C24D3bB59510BD783);
        setAddress("mainnet.curve.mim3Crv", 0x5a6A4D54456819380173272A5E8E9B9904BdF41B);
        setAddress("mainnet.aggregators.zeroXExchangProxy", 0x5a6A4D54456819380173272A5E8E9B9904BdF41B);

        // Optimism
        setAddress("optimism.op", 0x4200000000000000000000000000000000000042);
        setAddress("optimism.abraMultiSig", 0x4217AA01360846A849d2A89809d450D10248B513);
        setAddress("optimism.weth", 0x4200000000000000000000000000000000000006);
        setAddress("optimism.mim", 0xB153FB3d196A8eB25522705560ac152eeEc57901);
        setAddress("optimism.usdc", 0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
        setAddress("optimism.chainlink.op", 0xDEF1ABE32c034e558Cdd535791643C58a13aCC10);
        setAddress("optimism.chainlink.usdc", 0xDEF1ABE32c034e558Cdd535791643C58a13aCC10);
        setAddress("optimism.velodrome.velo", 0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);
        setAddress("optimism.velodrome.router", 0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);
        setAddress("optimism.velodrome.vOpUsdc", 0x47029bc8f5CBe3b464004E87eF9c9419a48018cd);
        setAddress("optimism.velodrome.factory", 0x25CbdDb98b35ab1FF77413456B31EC81A6B6B746);
        setAddress("optimism.velodrome.vOpUsdcGauge", 0x0299d40E99F2a5a1390261f5A71d13C3932E214C);
        setAddress("optimism.aggregators.zeroXExchangProxy", 0xDEF1ABE32c034e558Cdd535791643C58a13aCC10);

        pairCodeHash["optimism.velodrome"] = 0xc1ac28b1c4ebe53c0cff67bab5878c4eb68759bb1e9f73977cd266b247d149f0;
        pairCodeHash["avalanche.traderjoe"] = 0x0bbca9af0511ad1a1da383135cf3a8d2ac620e549ef9f6ae3a4c33c2fed0af91;
        pairCodeHash["fantom.spiritswap"] = 0xe242e798f6cee26a9cb0bbf24653bf066e5356ffeac160907fe2cc108e238617;
    }

    function initAddressLabels(Vm vm) public {
        for (uint256 i = 0; i < addressKeys.length; i++) {
            string memory key = addressKeys[i];
            vm.label(addressMap[key], key);
        }
    }

    function setAddress(string memory key, address value) public {
        require(addressMap[key] == address(0), string.concat("address already exists: ", key));
        addressMap[key] = value;
        addressKeys.push(key);
    }

    function getAddress(string calldata key) public view returns (address) {
        require(addressMap[key] != address(0), string.concat("address not found: ", key));
        return addressMap[key];
    }

    function getPairCodeHash(string calldata key) public view returns (bytes32) {
        require(pairCodeHash[key] != "", string.concat("pairCodeHash not found: ", key));
        return pairCodeHash[key];
    }
}
