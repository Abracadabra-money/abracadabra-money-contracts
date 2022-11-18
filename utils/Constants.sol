// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Vm.sol";

library ChainId {
    uint256 internal constant Mainnet = 1;
    uint256 internal constant BSC = 56;
    uint256 internal constant Polygon = 137;
    uint256 internal constant Fantom = 250;
    uint256 internal constant Optimism = 10;
    uint256 internal constant Arbitrum = 42161;
    uint256 internal constant Avalanche = 43114;
}

contract Constants {
    mapping(string => address) private addressMap;
    mapping(string => bytes32) private pairCodeHash;
    mapping(string => address[]) private cauldronsPerChain;
    mapping(string => mapping(address => bool)) private cauldronsPerChainExists;

    string[] private addressKeys;

    Vm private immutable vm;

    constructor(Vm _vm) {
        vm = _vm;

        setAddress("xMerlin", 0xfddfE525054efaAD204600d00CA86ADb1Cc2ea8a);

        // Mainnet
        setAddress("mainnet.ethereumWithdrawer", 0xB2c3A9c577068479B1E5119f6B7da98d25Ba48f4);
        setAddress("mainnet.cauldronV3", 0x3E2a2BC69E5C22A8DA4056B413621D1820Eb493E);
        setAddress("mainnet.cauldronV3_2", 0xE19B0D53B6416D139B2A447C3aE7fb9fe161A12c);
        setAddress("mainnet.cauldronV4", 0xA841011a3414D034e1275A9928c5c1EDDc4c3b9d);
        setAddress("mainnet.cauldronV3Whitelisted", 0xe0d2007F6F2A71B90143D6667257d95643183F2b);
        setAddress("mainnet.sushiBentoBox", 0xF5BCE5077908a1b7370B9ae04AdC565EBd643966);
        setAddress("mainnet.degenBox", 0xd96f48665a1410C0cd669A88898ecA36B9Fc2cce);
        setAddress("mainnet.multiSig", 0x5f0DeE98360d8200b20812e174d139A1a633EDd2);
        setAddress("mainnet.mimTreasury", 0xDF2C270f610Dc35d8fFDA5B453E74db5471E126B);
        setAddress("mainnet.devOps", 0x48c18844530c96AaCf24568fa7F912846aAc12B9);
        setAddress("mainnet.devOps.gelatoProxy", 0x5638f92019de4066c046864CA9eB36Ab17387490);
        setAddress("mainnet.wbtc", 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
        setAddress("mainnet.weth", 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        setAddress("mainnet.mim", 0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
        setAddress("mainnet.spell", 0x090185f2135308BaD17527004364eBcC2D37e5F6);
        setAddress("mainnet.usdc", 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        setAddress("mainnet.usdt", 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        setAddress("mainnet.ftt", 0x50D1c9771902476076eCFc8B2A83Ad6b9355a4c9);
        setAddress("mainnet.stargate.stg", 0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6);
        setAddress("mainnet.stargate.router", 0x8731d54E9D02c286767d56ac03e8037C07e01e98);
        setAddress("mainnet.stargate.usdcPool", 0xdf0770dF86a8034b3EFEf0A1Bb3c889B8332FF56);
        setAddress("mainnet.stargate.usdtPool", 0x38EA452219524Bb87e18dE1C24D3bB59510BD783);
        setAddress("mainnet.chainlink.mim", 0x7A364e8770418566e3eb2001A96116E6138Eb32F);
        setAddress("mainnet.chainlink.lusd", 0x3D7aE7E594f2f2091Ad8798313450130d0Aba3a0);
        setAddress("mainnet.liquity.lusd", 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);
        setAddress("mainnet.liquity.lqty", 0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D);
        setAddress("mainnet.liquity.stabilityPool", 0x66017D22b0f8556afDd19FC67041899Eb65a21bb);
        setAddress("mainnet.curve.mim3Crv", 0x5a6A4D54456819380173272A5E8E9B9904BdF41B);
        setAddress("mainnet.aggregators.zeroXExchangProxy", 0xDef1C0ded9bec7F1a1670819833240f027b25EfF);
        setAddress("mainnet.cauldronOwner", 0x8f788F226d36298dEb09A320956E3E3318Cba812);

        addCauldron("mainnet", "ALCX", 0x7b7473a76D6ae86CE19f7352A1E89F6C9dc39020);
        addCauldron("mainnet", "AGLD", 0xc1879bf24917ebE531FbAA20b0D05Da027B592ce);
        addCauldron("mainnet", "FTT", 0x9617b633EF905860D919b88E1d9d9a6191795341);
        addCauldron("mainnet", "LUSD", 0x8227965A7f42956549aFaEc319F4E444aa438Df5);
        addCauldron("mainnet", "SHIB", 0x252dCf1B621Cc53bc22C256255d2bE5C8c32EaE4);
        addCauldron("mainnet", "SPELL", 0xCfc571f3203756319c231d3Bc643Cee807E74636);
        addCauldron("mainnet", "Stargate USDC", 0xd31E19A0574dBF09310c3B06f3416661B4Dc7324);
        addCauldron("mainnet", "Stargate USDT", 0xc6B2b3fE7c3D7a6f823D9106E22e66660709001e);
        addCauldron("mainnet", "WBTC", 0x5ec47EE69BEde0b6C2A2fC0D9d094dF16C192498);
        addCauldron("mainnet", "WETH", 0x390Db10e65b5ab920C19149C919D970ad9d18A41);
        addCauldron("mainnet", "cvx3pool", 0x257101F20cB7243E2c7129773eD5dBBcef8B34E0);
        addCauldron("mainnet", "cvxrenCrv", 0x35a0Dd182E4bCa59d5931eae13D0A2332fA30321);
        addCauldron("mainnet", "cvxtricrypto2", 0x4EAeD76C3A388f4a841E9c765560BBe7B3E4B3A0);
        addCauldron("mainnet", "sSPELL", 0x3410297D89dCDAf4072B805EFc1ef701Bb3dd9BF);
        addCauldron("mainnet", "xSUSHI", 0x98a84EfF6e008c5ed0289655CcdCa899bcb6B99F);
        addCauldron("mainnet", "yvCVXETH", 0xf179fe36a36B32a4644587B8cdee7A23af98ed37);
        addCauldron("mainnet", "yvDAI", 0x7Ce7D9ED62B9A6c5aCe1c6Ec9aeb115FA3064757);
        addCauldron("mainnet", "yvWETH v2", 0x920D9BD936Da4eAFb5E25c6bDC9f6CB528953F9f);
        addCauldron("mainnet", "yvcrvIB", 0xEBfDe87310dc22404d918058FAa4D56DC4E93f0A);
        addCauldron("mainnet", "yvSTETH2", 0x53375adD9D2dFE19398eD65BAaEFfe622760A9A6);

        // Optimism
        setAddress("optimism.degenBox", 0xa93C81f564579381116ee3E007C9fCFd2EBa1723);
        setAddress("optimism.cauldronV3_2", 0xB6957806b7fD389323628674BCdFCD61b9cc5e02);
        setAddress("optimism.op", 0x4200000000000000000000000000000000000042);
        setAddress("optimism.abraMultiSig", 0x4217AA01360846A849d2A89809d450D10248B513);
        setAddress("optimism.weth", 0x4200000000000000000000000000000000000006);
        setAddress("optimism.mim", 0xB153FB3d196A8eB25522705560ac152eeEc57901);
        setAddress("optimism.usdc", 0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
        setAddress("optimism.dai", 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
        setAddress("optimism.chainlink.op", 0x0D276FC14719f9292D5C1eA2198673d1f4269246);
        setAddress("optimism.chainlink.usdc", 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3);
        setAddress("optimism.velodrome.velo", 0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);
        setAddress("optimism.velodrome.router", 0xa132DAB612dB5cB9fC9Ac426A0Cc215A3423F9c9);
        setAddress("optimism.velodrome.vOpUsdc", 0x47029bc8f5CBe3b464004E87eF9c9419a48018cd);
        setAddress("optimism.velodrome.factory", 0x25CbdDb98b35ab1FF77413456B31EC81A6B6B746);
        setAddress("optimism.velodrome.vOpUsdcGauge", 0x0299d40E99F2a5a1390261f5A71d13C3932E214C);
        setAddress("optimism.aggregators.zeroXExchangProxy", 0xDEF1ABE32c034e558Cdd535791643C58a13aCC10);
        setAddress("optimism.bridges.anyswapRouter", 0xDC42728B0eA910349ed3c6e1c9Dc06b5FB591f98);
        setAddress("optimism.stargate.stg", 0x296F55F8Fb28E498B858d0BcDA06D955B2Cb3f97);
        setAddress("optimism.stargate.router", 0xB0D502E938ed5f4df2E681fE6E419ff29631d62b);
        setAddress("optimism.stargate.usdcPool", 0xDecC0c09c3B5f6e92EF4184125D5648a66E35298);
        setAddress("optimism.stargate.staking", 0x4DeA9e918c6289a52cd469cAC652727B7b412Cd2);

        addCauldron("optimism", "Velodrome vOP/USDC", 0x68f498C230015254AFF0E1EB6F85Da558dFf2362);

        // Fantom
        setAddress("fantom.degenBox", 0x74A0BcA2eeEdf8883cb91E37e9ff49430f20a616);
        setAddress("fantom.mim", 0x82f0B8B456c1A451378467398982d4834b6829c1);
        setAddress("fantom.wftm", 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
        setAddress("fantom.spookyswap.wFtmMim", 0x6f86e65b255c9111109d2D2325ca2dFc82456efc);
        setAddress("fantom.spookyswap.factory", 0x152eE697f2E276fA89E96742e9bB9aB1F2E61bE3);
        setAddress("fantom.spookyswap.router", 0xF491e7B69E4244ad4002BC14e878a34207E38c29);
        setAddress("fantom.spookyswap.boo", 0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE);
        setAddress("fantom.spookyswap.farmV2", 0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD);

        addCauldron("fantom", "FTM", 0x8E45Af6743422e488aFAcDad842cE75A09eaEd34);
        addCauldron("fantom", "FTM", 0xd4357d43545F793101b592bACaB89943DC89d11b);
        addCauldron("fantom", "yvWFTM", 0xed745b045f9495B8bfC7b58eeA8E0d0597884e12);
        addCauldron("fantom", "xBOO", 0xa3Fc1B4b7f06c2391f7AD7D4795C1cD28A59917e);
        addCauldron("fantom", "FTM/MIM Spirit", 0x7208d9F9398D7b02C5C22c334c2a7A3A98c0A45d);
        addCauldron("fantom", "FTM/MIM Spooky", 0x4fdfFa59bf8dda3F4d5b38F260EAb8BFaC6d7bC1);

        // Avalanche
        setAddress("avalanche.mim", 0x130966628846BFd36ff31a822705796e8cb8C18D);
        setAddress("avalanche.degenBox1", 0xf4F46382C2bE1603Dc817551Ff9A7b333Ed1D18f);
        setAddress("avalanche.degenBox2", 0x1fC83f75499b7620d53757f0b01E2ae626aAE530);

        addCauldron("avalanche", "AVAX", 0x3CFEd0439aB822530b1fFBd19536d897EF30D2a2);
        addCauldron("avalanche", "AVAX/MIM SLP", 0xAcc6821d0F368b02d223158F8aDA4824dA9f28E3);

        // Arbitrum
        setAddress("arbitrum.mim", 0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A);
        setAddress("arbitrum.sushiBentoBox", 0x74c764D41B77DBbb4fe771daB1939B00b146894A);
        setAddress("arbitrum.cauldronV3_1", 0xd98bfb05DD6aa37BA5624479Eb4264de9a3384Ee);
        setAddress("arbitrum.cauldronV4", 0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A); // TODO
        setAddress("arbitrum.degenBox", 0x7C8FeF8eA9b1fE46A7689bfb8149341C90431D38);
        setAddress("arbitrum.weth", 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        setAddress("arbitrum.usdc", 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
        setAddress("arbitrum.usdt", 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
        setAddress("arbitrum.gmx.glp", 0x4277f8F2c384827B5273592FF7CeBd9f2C1ac258);
        setAddress("arbitrum.gmx.glpManager", 0x321F653eED006AD1C29D174e17d96351BDe22649);
        setAddress("arbitrum.gmx.sGLP", 0x2F546AD4eDD93B956C8999Be404cdCAFde3E89AE);
        setAddress("arbitrum.gmx.fGLP", 0x4e971a87900b931fF39d1Aad67697F49835400b6);
        setAddress("arbitrum.gmx.fsGLP", 0x1aDDD80E6039594eE970E5872D247bf0414C8903);
        setAddress("arbitrum.gmx.rewardRouterV2", 0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1);

        addCauldron("arbitrum", "WETH", 0xC89958B03A55B5de2221aCB25B58B89A000215E6);

        // BSC
        setAddress("bsc.mim", 0xfE19F0B51438fd612f6FD59C1dbB3eA319f433Ba);
        addCauldron("bsc", "BNB", 0x692CF15F80415D83E8c0e139cAbcDA67fcc12C90);
        addCauldron("bsc", "CAKE", 0xF8049467F3A9D50176f4816b20cDdd9bB8a93319);

        pairCodeHash["optimism.velodrome"] = 0xc1ac28b1c4ebe53c0cff67bab5878c4eb68759bb1e9f73977cd266b247d149f0;
        pairCodeHash["avalanche.traderjoe"] = 0x0bbca9af0511ad1a1da383135cf3a8d2ac620e549ef9f6ae3a4c33c2fed0af91;
        pairCodeHash["fantom.spiritswap"] = 0xe242e798f6cee26a9cb0bbf24653bf066e5356ffeac160907fe2cc108e238617;
        pairCodeHash["fantom.spookyswap"] = 0xcdf2deca40a0bd56de8e3ce5c7df6727e5b1bf2ac96f283fa9c4b3e6b42ea9d2;
    }

    function setAddress(string memory key, address value) public {
        require(addressMap[key] == address(0), string.concat("address already exists: ", key));
        addressMap[key] = value;
        addressKeys.push(key);
        vm.label(value, key);
    }

    function addCauldron(
        string memory chain,
        string memory name,
        address value
    ) public {
        require(!cauldronsPerChainExists[chain][value], string.concat("cauldron already added: ", vm.toString(value)));
        cauldronsPerChainExists[chain][value] = true;
        cauldronsPerChain[chain].push(value);
        vm.label(value, string.concat("cauldron.", name));
    }

    function getCauldrons(string calldata chain) public view returns (address[] memory) {
        return cauldronsPerChain[chain];
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
