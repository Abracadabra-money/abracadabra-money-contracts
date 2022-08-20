// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/ERC20.sol";
import "forge-std/Script.sol";
import "oracles/SolidlyStableOracle.sol";
import "utils/BaseTest.sol";
import "interfaces/IVelodromePairFactory.sol";
import "forge-std/console2.sol";

contract SolidlyStableOracleTest is BaseTest {
    struct Info {
        address pair;
        address oracleA;
        address oracleB;
    }

    Info[] pairs;

    function setUp() public override {
        super.setUp();

        pairs.push(
            Info({
                pair: 0xd16232ad60188B68076a235c65d692090caba155,
                oracleA: 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3, // usdc
                oracleB: 0x7f99817d87baD03ea21E05112Ca799d715730efe // susd
            })
        );

        pairs.push(
            Info({
                pair: 0x4F7ebc19844259386DBdDB7b2eB759eeFc6F8353,
                oracleA: 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3, // usdc
                oracleB: 0x8dBa75e83DA73cc766A7e5a0ee71F656BAb470d6 // dai
            })
        );

        pairs.push(
            Info({
                pair: 0xAdF902b11e4ad36B227B84d856B229258b0b0465,
                oracleA: 0xc7D132BeCAbE7Dcc4204841F33bae45841e41D9C, // frax
                oracleB: 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3 // usdc
            })
        );

        pairs.push(
            Info({
                pair: 0xaC49498B97312A6716EF312F389B7e4D183A2A7C,
                oracleA: 0xc7D132BeCAbE7Dcc4204841F33bae45841e41D9C, // frax
                oracleB: 0x7f99817d87baD03ea21E05112Ca799d715730efe // susd
            })
        );

        pairs.push(
            Info({
                pair: 0xEc24EB97cEc2F0F6A2D61254990B0f163BbbFe1d,
                oracleA: 0x7f99817d87baD03ea21E05112Ca799d715730efe, // susd
                oracleB: 0x8dBa75e83DA73cc766A7e5a0ee71F656BAb470d6 // dai
            })
        );

        pairs.push(
            Info({
                pair: 0xe8633Ce5d216EBfDdDF6875067DFb8397dedcaF3,
                oracleA: 0x0D276FC14719f9292D5C1eA2198673d1f4269246, // op
                oracleB: 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3 // usdc
            })
        );

        pairs.push(
            Info({
                pair: 0x278631eFe7e7B4C2eC49927b255c2Ca42be2C1b1,
                oracleA: 0x13e3Ee699D1909E989722E753853AE30b17e08c5, // weth
                oracleB: 0x0D276FC14719f9292D5C1eA2198673d1f4269246 // op
            })
        );

        pairs.push(
            Info({
                pair: 0xb840ADAe1a31b52778188B9E948Fc79A4Bc99D44,
                oracleA: 0x2FCF37343e916eAEd1f1DdaaF84458a359b53877, // snx
                oracleB: 0x7f99817d87baD03ea21E05112Ca799d715730efe // susd
            })
        );
        pairs.push(
            Info({
                pair: 0x48e18E3d1eFA7F0E15F1b2Bf01b232534c30a3EF,
                oracleA: 0x13e3Ee699D1909E989722E753853AE30b17e08c5, // weth
                oracleB: 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3 // usdc
            })
        );

        pairs.push(
            Info({
                pair: 0xc8F51393fe595F3f3A3cAAd164D781b7f4A596dD,
                oracleA: 0x7f99817d87baD03ea21E05112Ca799d715730efe, // susd
                oracleB: 0xECef79E109e997bCA29c1c0897ec9d7b03647F5E // usdt
            })
        );
    }

    function test_fair_price_compared_to_real_price() public {
        // around a week span,
        uint256 samplePerDay = 1;
        uint256 steps = samplePerDay * 7;
        uint256 blockStart = 18919935;
        uint256 blockNo = 18919935;
        uint256 blockStep = (19784578 - blockStart) / steps;

        for (uint256 i = 0; i < pairs.length; i++) {
            blockNo = blockStart;
            console2.log(pairs[i].pair);

            uint256 totalAbsDiff = 0;
            for (uint256 j = 0; j < steps; j++) {
                console2.log("");
                console2.log("block", blockNo);

                forkOptimism(blockNo);
                uint256 absDiff = _testPair(ISolidlyPair(pairs[i].pair), IAggregator(pairs[i].oracleA), IAggregator(pairs[i].oracleB));
                assertLe(absDiff, 30);
                totalAbsDiff += absDiff;
                blockNo += blockStep;
            }
            console2.log("");
            console.log("-> avg diff", totalAbsDiff / steps, "bips");
            console2.log("____");
            console2.log("");
        }
    }

    function test_pair_skewing_manipulation_high_liquidity() public {
        forkOptimism(19920283);
        initConfig();

        address usdcWhale = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;
        ERC20 usdc = ERC20(constants.getAddress("optimism.usdc"));
        ISolidlyPair pair = ISolidlyPair(0x4F7ebc19844259386DBdDB7b2eB759eeFc6F8353); // usdc/dai pair

        IAggregator oracle0 = IAggregator(0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3);
        IAggregator oracle1 = IAggregator(0x8dBa75e83DA73cc766A7e5a0ee71F656BAb470d6);

        SolidlyStableOracle oracle = new SolidlyStableOracle(pair, oracle0, oracle1);

        console2.log("before skewing:");
        console.log("reserver0:", pair.reserve0(), "reserve1:", pair.reserve1());

        _testPairWithOracle(oracle, pair, oracle0, oracle1);

        vm.prank(usdcWhale);
        usdc.approve(address(pair), type(uint256).max);

        // 25%

        uint256 snapshotId = vm.snapshot();

        // 25%
        {
            uint256 amountIn = pair.reserve0();
            amountIn = amountIn / 4;
            vm.startPrank(usdcWhale);
            usdc.transfer(address(pair), amountIn);
            uint256 amountOut = pair.getAmountOut(amountIn, address(usdc));

            pair.swap(0, amountOut, usdcWhale, "");
            vm.stopPrank();

            console2.log("");
            console2.log("after skewing 75%:");
            console.log("reserver0:", pair.reserve0(), "reserve1:", pair.reserve1());
            _testPairWithOracle(oracle, pair, oracle0, oracle1);
            vm.revertTo(snapshotId);
        }

        // 50%
        {
            uint256 amountIn = pair.reserve0();
            amountIn = amountIn / 2;
            vm.startPrank(usdcWhale);
            usdc.transfer(address(pair), amountIn);
            uint256 amountOut = pair.getAmountOut(amountIn, address(usdc));

            pair.swap(0, amountOut, usdcWhale, "");
            vm.stopPrank();

            console2.log("");
            console2.log("after skewing 50%:");
            console.log("reserver0:", pair.reserve0(), "reserve1:", pair.reserve1());
            _testPairWithOracle(oracle, pair, oracle0, oracle1);
            vm.revertTo(snapshotId);
        }

        // 75%
        {
            uint256 amountIn = pair.reserve0();
            amountIn = amountIn / 2 + amountIn / 4;
            vm.startPrank(usdcWhale);
            usdc.transfer(address(pair), amountIn);
            uint256 amountOut = pair.getAmountOut(amountIn, address(usdc));

            pair.swap(0, amountOut, usdcWhale, "");
            vm.stopPrank();

            console2.log("");
            console2.log("after skewing 75%:");
            console.log("reserver0:", pair.reserve0(), "reserve1:", pair.reserve1());
            _testPairWithOracle(oracle, pair, oracle0, oracle1);
            vm.revertTo(snapshotId);
        }

        // 100%
        {
            uint256 amountIn = pair.reserve0();
            vm.startPrank(usdcWhale);
            usdc.transfer(address(pair), amountIn);
            uint256 amountOut = pair.getAmountOut(amountIn, address(usdc));

            pair.swap(0, amountOut, usdcWhale, "");
            vm.stopPrank();

            console2.log("");
            console2.log("after skewing 100%:");
            console.log("reserver0:", pair.reserve0(), "reserve1:", pair.reserve1());
            _testPairWithOracle(oracle, pair, oracle0, oracle1);
            vm.revertTo(snapshotId);
        }
    }

    function test_pair_skewing_manipulation_low_liquidity() public {}

    function _testPair(
        ISolidlyPair pair,
        IAggregator oracle0,
        IAggregator oracle1
    ) private returns (uint256 absDiff) {
        SolidlyStableOracle oracle = new SolidlyStableOracle(pair, oracle0, oracle1);
        return _testPairWithOracle(oracle, pair, oracle0, oracle1);
    }

    function _testPairWithOracle(
        SolidlyStableOracle oracle,
        ISolidlyPair pair,
        IAggregator oracle0,
        IAggregator oracle1
    ) private returns (uint256 absDiff) {
        uint256 feed = uint256(oracle.latestAnswer());
        uint256 realPrice = _poolLpPrice(pair, oracle0, oracle1);
        console2.log("fair price:", feed / 1e18);
        console2.log("real price:", realPrice / 1e18);

        if (feed > realPrice) {
            absDiff = ((feed - realPrice) * 10000) / realPrice;
            console2.log("+", absDiff, "bips");
        } else {
            absDiff = ((realPrice - feed) * 10000) / feed;
            console2.log("+", absDiff, "bips");
        }
    }

    function _poolLpPrice(
        ISolidlyPair pair,
        IAggregator oracle0,
        IAggregator oracle1
    ) private view returns (uint256) {
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        (, int256 price0, , , ) = oracle0.latestRoundData();
        (, int256 price1, , , ) = oracle1.latestRoundData();
        uint256 normalizedReserve0 = reserve0 * (10**(18 - IStrictERC20(pair.token0()).decimals()));
        uint256 normalizedReserve1 = reserve1 * (10**(18 - IStrictERC20(pair.token1()).decimals()));
        uint256 normalizedPrice0 = uint256(price0) * (10**(18 - oracle0.decimals()));
        uint256 normalizedPrice1 = uint256(price1) * (10**(18 - oracle1.decimals()));

        return ((normalizedReserve0 * normalizedPrice0) + (normalizedReserve1 * normalizedPrice1)) / pair.totalSupply();
    }
}
