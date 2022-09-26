// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/ERC20.sol";
import "forge-std/Script.sol";
import "oracles/SolidlyStableOracle.sol";
import "utils/BaseTest.sol";
import "interfaces/IVelodromePairFactory.sol";
import "interfaces/ISolidlyRouter.sol";
import "mocks/OracleMock.sol";
import "mocks/ERC20WithBellsMock.sol";
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

    function x_test_fair_price_compared_to_real_price() public {
        uint256 blockStart = 13405868; // around 55 days ago
        uint256 blockNo = blockStart;

        uint256 steps = 60 * 10; // 10 samples per day
        uint256 blockStep = (20044722 - blockStart) / steps;

        try vm.removeFile("cache/out.csv") {} catch {}
        vm.writeLine("cache/out.csv", string.concat("pair;block;real_price;fair_price;diff_bips"));

        for (uint256 i = 0; i < pairs.length; i++) {
            blockNo = blockStart;
            console2.log(pairs[i].pair);

            for (uint256 j = 0; j < steps; j++) {
                forkOptimism(blockNo);
                (uint256 realPrice, uint256 fairPrice, int256 diff) = _testPair(
                    ISolidlyPair(pairs[i].pair),
                    IAggregator(pairs[i].oracleA),
                    IAggregator(pairs[i].oracleB)
                );
                blockNo += blockStep;
                vm.writeLine(
                    "cache/out.csv",
                    string.concat(
                        vm.toString(pairs[i].pair),
                        ";",
                        vm.toString(blockNo),
                        ";",
                        vm.toString(realPrice),
                        ";",
                        vm.toString(fairPrice),
                        ";",
                        vm.toString(diff)
                    )
                );
            }
        }
    }

    function x_test_pair_skewing_manipulation() public {
        forkOptimism(19920283);
        super.setUp();

        address usdcWhale = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;
        ERC20 usdc = ERC20(constants.getAddress("optimism.usdc"));
        ISolidlyPair pair = ISolidlyPair(0x4F7ebc19844259386DBdDB7b2eB759eeFc6F8353); // usdc/dai pair
        IAggregator oracle0 = IAggregator(0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3);
        IAggregator oracle1 = IAggregator(0x8dBa75e83DA73cc766A7e5a0ee71F656BAb470d6);

        SolidlyStableOracle oracle = new SolidlyStableOracle(pair, oracle0, oracle1);

        console2.log("before skewing:");
        console2.log("reserve0:", pair.reserve0(), "reserve1:", pair.reserve1());

        _testPairWithOracle(oracle, pair, oracle0, oracle1);

        vm.prank(usdcWhale);
        usdc.approve(address(pair), type(uint256).max);

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
            console2.log("after skewing 25%:");
            console2.log("in:", amountIn, ", out:", amountOut);
            console2.log("ratio:", amountOut / amountIn / 1e7);
            console2.log("reserve0:", pair.reserve0(), "reserve1:", pair.reserve1());
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
            console2.log("in:", amountIn, ", out:", amountOut);
            console2.log("ratio:", amountOut / amountIn / 1e7);
            console2.log("reserve0:", pair.reserve0(), "reserve1:", pair.reserve1());
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
            console2.log("in:", amountIn, ", out:", amountOut);
            console2.log("ratio:", amountOut / amountIn / 1e7);
            console2.log("reserve0:", pair.reserve0(), "reserve1:", pair.reserve1());
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
            console2.log("in:", amountIn, ", out:", amountOut);
            console2.log("ratio:", amountOut / amountIn / 1e7);
            console2.log("reserve0:", pair.reserve0(), "reserve1:", pair.reserve1());
            _testPairWithOracle(oracle, pair, oracle0, oracle1);
            vm.revertTo(snapshotId);
        }

        // 1000%
        {
            uint256 amountIn = pair.reserve0() * 5;
            vm.startPrank(usdcWhale);
            usdc.transfer(address(pair), amountIn);
            uint256 amountOut = pair.getAmountOut(amountIn, address(usdc));

            pair.swap(0, amountOut, usdcWhale, "");
            vm.stopPrank();

            console2.log("");
            console2.log("after skewing 500%:");
            console2.log("in:", amountIn, ", out:", amountOut);
            console2.log("ratio:", amountOut / amountIn / 1e7);
            console2.log("reserve0:", pair.reserve0(), "reserve1:", pair.reserve1());
            _testPairWithOracle(oracle, pair, oracle0, oracle1);
            vm.revertTo(snapshotId);
        }
    }

    struct test_with_adding_liquidity_struct {
        address usdcWhale;
        address daiWhale;
        ERC20 usdc;
        ERC20 dai;
        ISolidlyPair pair;
        IAggregator oracle0;
        IAggregator oracle1;
    }

    function x_test_with_adding_liquidity() public {
        forkOptimism(19920283);
        super.setUp();

        test_with_adding_liquidity_struct memory d = test_with_adding_liquidity_struct({
            usdcWhale: 0x625E7708f30cA75bfd92586e17077590C60eb4cD,
            daiWhale: 0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE,
            usdc: ERC20(constants.getAddress("optimism.usdc")),
            dai: ERC20(constants.getAddress("optimism.dai")),
            pair: ISolidlyPair(0x4F7ebc19844259386DBdDB7b2eB759eeFc6F8353), // usdc/dai pair
            oracle0: IAggregator(0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3),
            oracle1: IAggregator(0x8dBa75e83DA73cc766A7e5a0ee71F656BAb470d6)
        });

        SolidlyStableOracle oracle = new SolidlyStableOracle(d.pair, d.oracle0, d.oracle1);
        console2.log("before skewing:");
        console2.log("reserve0:", d.pair.reserve0(), "reserve1:", d.pair.reserve1());

        _testPairWithOracle(oracle, d.pair, d.oracle0, d.oracle1);

        vm.startPrank(d.daiWhale);
        d.dai.transfer(d.usdcWhale, d.dai.balanceOf(d.daiWhale));
        vm.stopPrank();

        vm.startPrank(d.usdcWhale);
        d.usdc.approve(constants.getAddress("optimism.velodrome.router"), type(uint256).max);
        d.dai.approve(constants.getAddress("optimism.velodrome.router"), type(uint256).max);

        ISolidlyRouter(constants.getAddress("optimism.velodrome.router")).addLiquidity(
            address(d.usdc),
            address(d.dai),
            true,
            d.usdc.balanceOf(d.usdcWhale),
            d.dai.balanceOf(d.usdcWhale),
            0,
            0,
            d.usdcWhale,
            type(uint256).max
        );
        vm.stopPrank();

        console2.log("after liquidity providing");
        console2.log("reserve0:", d.pair.reserve0(), "reserve1:", d.pair.reserve1());
        _testPairWithOracle(oracle, d.pair, d.oracle0, d.oracle1);
    }

    function x_test_with_weird_prices() public {
        forkOptimism(19920283);
        super.setUp();

        ISolidlyPair pair = ISolidlyPair(0x4F7ebc19844259386DBdDB7b2eB759eeFc6F8353); // usdc/dai pair
        IAggregator realSource0 = IAggregator(0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3);
        IAggregator realSource1 = IAggregator(0x8dBa75e83DA73cc766A7e5a0ee71F656BAb470d6);

        OracleMock mockSource0 = new OracleMock();
        OracleMock mockSource1 = new OracleMock();

        uint8 decimals0 = realSource0.decimals();
        uint8 decimals1 = realSource1.decimals();

        console2.log("decimals0:", decimals0, ", decimals1:", decimals1);

        int256 realPrice0 = realSource0.latestAnswer();
        int256 realPrice1 = realSource1.latestAnswer();

        mockSource0.setDecimals(decimals0);
        mockSource0.setPrice(realPrice0);
        mockSource1.setDecimals(decimals1);
        mockSource1.setPrice(realPrice1);

        SolidlyStableOracle realOracle = new SolidlyStableOracle(pair, realSource0, realSource1);
        SolidlyStableOracle mockOracle = new SolidlyStableOracle(pair, mockSource0, mockSource1);

        console2.log("\nOriginal oracle");
        _testPairWithOracle(realOracle, pair, realSource0, realSource1);

        console2.log("\nMock oracle -- initial conditions:");
        _testPairWithOracle(mockOracle, pair, mockSource0, mockSource1);

        // Since it's special-cased, make sure we actually hit that path.
        // Would expect it to be a little lower than the real value:
        // the actual reserves reflect a price that is not exactly equal.
        console2.log("\nMock oracle -- exactly equal prices (0):");
        mockSource1.setPrice(realPrice0);
        _testPairWithOracle(mockOracle, pair, mockSource0, mockSource1);
        mockSource1.setPrice(realPrice1);

        console2.log("\nMock oracle -- exactly equal prices (1):");
        mockSource0.setPrice(realPrice1);
        _testPairWithOracle(mockOracle, pair, mockSource0, mockSource1);
        mockSource0.setPrice(realPrice0);

        // OK now we're facing the problem that the oracle is not trading at
        // the true price; unless there's an easy way to arb it we should
        // probably just set up a mock with corresponding prices.
        // At least it's not crashing.

        console2.log("\nMock oracle -- somewhat out of balance:");
        mockSource0.setPrice(realPrice0 / 2);
        _testPairWithOracle(mockOracle, pair, mockSource0, mockSource1);

        console2.log("\nMock oracle -- special-case out of balance:");
        mockSource0.setPrice(realPrice0 / 2e6);
        _testPairWithOracle(mockOracle, pair, mockSource0, mockSource1);
    }

    function test_with_dumping_token() public {
        forkOptimism(19920283);
        super.setUp();

        // Fake tokens and a fake pair, so that we can manipulate the price
        // and check the oracle does not overestimate the value of the LPs
        // (too much) as one side drops towards zero.
        ERC20WithBellsMock token0 = new ERC20WithBellsMock(type(uint256).max, 8, "APPLE");
        ERC20WithBellsMock token1 = new ERC20WithBellsMock(type(uint256).max, 8, "BANANA");
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        ISolidlyPair pair = ISolidlyPair(
            IVelodromePairFactory(constants.getAddress("optimism.velodrome.factory")).createPair(address(token0), address(token1), true)
        );
        token0.approve(address(pair), type(uint256).max);
        token1.approve(address(pair), type(uint256).max);

        ISolidlyRouter router = ISolidlyRouter(constants.getAddress("optimism.velodrome.router"));
        token0.approve(address(router), type(uint256).max);
        token1.approve(address(router), type(uint256).max);
        router.addLiquidity(
            address(token0),
            address(token1),
            true,
            10_000 * 10**token0.decimals(),
            10_000 * 10**token1.decimals(),
            0,
            0,
            msg.sender,
            type(uint256).max
        );

        OracleMock oracle0 = new OracleMock();
        OracleMock oracle1 = new OracleMock();
        oracle0.setDecimals(token0.decimals());
        oracle1.setDecimals(token1.decimals());
        oracle0.setPrice(int256(1 * 10**token0.decimals()));
        oracle1.setPrice(int256(1 * 10**token1.decimals()));

        SolidlyStableOracle oraclePair = new SolidlyStableOracle(pair, oracle0, oracle1);

        console2.log("\nInitial, fully stable, situation:");
        _testPairWithOracle(oraclePair, pair, oracle0, oracle1);

        console2.log("\nJust drop to 99.999%");
        oracle1.setPrice(int256((10**token1.decimals() * 99_999) / 100_000));
        _testPairWithOracle(oraclePair, pair, oracle0, oracle1);

        console2.log("\nJust drop to 50%");
        oracle1.setPrice(int256((10**token1.decimals() * 50) / 100));
        _testPairWithOracle(oraclePair, pair, oracle0, oracle1);

        console2.log("\nDrop and arb to 99.999%");
        oracle1.setPrice(int256((10**token1.decimals() * 99_999) / 100_000));
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _testPairWithOracle(oraclePair, pair, oracle0, oracle1);

        console2.log("\nDrop and arb to 99%");
        oracle1.setPrice(int256((10**token1.decimals() * 99) / 100));
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _testPairWithOracle(oraclePair, pair, oracle0, oracle1);

        console2.log("\nDrop and arb to 97%");
        oracle1.setPrice(int256((10**token1.decimals() * 97) / 100));
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _testPairWithOracle(oraclePair, pair, oracle0, oracle1);

        console2.log("\nDrop and arb to 85%");
        oracle1.setPrice(int256((10**token1.decimals() * 85) / 100));
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _testPairWithOracle(oraclePair, pair, oracle0, oracle1);

        console2.log("\nDrop and arb to 70%");
        oracle1.setPrice(int256((10**token1.decimals() * 70) / 100));
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _testPairWithOracle(oraclePair, pair, oracle0, oracle1);

        console2.log("\nDrop and arb to 50%");
        oracle1.setPrice(int256((10**token1.decimals() * 50) / 100));
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _testPairWithOracle(oraclePair, pair, oracle0, oracle1);

        console2.log("\nDrop and arb to 25%");
        oracle1.setPrice(int256((10**token1.decimals() * 25) / 100));
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _testPairWithOracle(oraclePair, pair, oracle0, oracle1);

        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        // TODO: Why does this decide to buy back some tokens? The last run
        //       should not have overshot it. Nevertheless the numbers seem
        //       close enough for now...
        console2.log("\nDrop and arb to 25%");
        oracle1.setPrice(int256((10**token1.decimals() * 25) / 100));
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _testPairWithOracle(oraclePair, pair, oracle0, oracle1);

        console2.log("\nDrop and arb to 5%");
        oracle1.setPrice(int256((10**token1.decimals() * 5) / 100));
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _testPairWithOracle(oraclePair, pair, oracle0, oracle1);

        console2.log("\nDrop and arb to 1%");
        oracle1.setPrice(int256((10**token1.decimals() * 1) / 100));
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _testPairWithOracle(oraclePair, pair, oracle0, oracle1);

        console2.log("\nDrop and arb to 0.1%");
        oracle1.setPrice(int256((10**token1.decimals() * 1) / 1000));
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _testPairWithOracle(oraclePair, pair, oracle0, oracle1);

        console2.log("\nDrop and arb to 0.01%");
        oracle1.setPrice(int256((10**token1.decimals() * 1) / 10000));
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _testPairWithOracle(oraclePair, pair, oracle0, oracle1);

        console2.log("\nDrop and arb to 0.001%");
        oracle1.setPrice(int256((10**token1.decimals() * 1) / 100000));
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _testPairWithOracle(oraclePair, pair, oracle0, oracle1);

        console2.log("\nDrop and arb to 0.0001%");
        oracle1.setPrice(int256((10**token1.decimals() * 1) / 1000000));
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _arbPairToTruePrice(pair, oracle0, oracle1);
        _testPairWithOracle(oraclePair, pair, oracle0, oracle1);
    }

    function _testPair(
        ISolidlyPair pair,
        IAggregator oracle0,
        IAggregator oracle1
    )
        private
        returns (
            uint256 realPrice,
            uint256 fairPrice,
            int256 diff
        )
    {
        SolidlyStableOracle oracle = new SolidlyStableOracle(pair, oracle0, oracle1);
        return _testPairWithOracle(oracle, pair, oracle0, oracle1);
    }

    function _testPairWithOracle(
        SolidlyStableOracle oracle,
        ISolidlyPair pair,
        IAggregator oracle0,
        IAggregator oracle1
    )
        private
        view
        returns (
            uint256 realPrice,
            uint256 fairPrice,
            int256 diff
        )
    {
        fairPrice = uint256(oracle.latestAnswer());
        realPrice = _poolLpPrice(pair, oracle0, oracle1);
        console2.log("fair price:", fairPrice / 1e18);
        console2.log("real price:", realPrice / 1e18);

        diff = ((int256(fairPrice) - int256(realPrice)) * 10_000) / int256(realPrice);
        if (diff < 0) {
            console2.log("diff:", uint256(-diff), "bps under");
        } else if (diff > 0) {
            console2.log("diff:", uint256(diff), "bps over");
        } else {
            console2.log("diff: 0");
        }
    }

    // Ensure reserves (more or less) match what we would expect given "real"
    // prices. Does not use the theoretical formula as that is what we are
    // testing.
    // The only assumption we make is that the "profits on a trade" curve is
    // concave: selling a small amount results in roughly the pricing "error",
    // and beyond some maximum profits will start going down. Beyond that, the
    // pricing mechanism is treated as a black box.
    function _arbPairToTruePrice(
        ISolidlyPair pair,
        IAggregator oracle0,
        IAggregator oracle1
    ) private {
        address token0 = pair.token0();
        address token1 = pair.token1();

        uint256 pIn;
        uint256 pOut;
        address tokenIn;
        uint256 min = 100;
        // Sort out whether and in which direction we will trade. Defauls to
        // selling token1.
        {
            uint256 p0 = uint256(oracle0.latestAnswer());
            uint256 p1 = uint256(oracle1.latestAnswer());
            uint256 proceeds = p0 * pair.getAmountOut(min, token1);
            if (proceeds < p1 * min) {
                // Selling a small amount of the supposedly overvalued token
                // is not profitable. Check if we got the order wrong:
                proceeds = p1 * pair.getAmountOut(min, token0);
                if (proceeds < p0 * min) {
                    // Neither direction is profitable. We are done.
                    return;
                }
                tokenIn = token0;
                pIn = p0;
                pOut = p1;
            } else {
                tokenIn = token1;
                pIn = p1;
                pOut = p0;
            }
        }

        (uint256 amountIn, uint256 amountOut) = _findBestTradeSize(pair, tokenIn, pIn, pOut, min);

        ERC20(tokenIn).transfer(address(pair), amountIn);
        if (tokenIn == token1) {
            pair.swap(amountOut, 0, msg.sender, "");
            console2.log("Sold", amountIn, "for", amountOut);
        } else {
            pair.swap(0, amountOut, msg.sender, "");
            console2.log("Bought", amountIn, "for", amountOut);
        }
    }

    // Part of the arbing process; separated for stack depth reasons.
    // Assumes trading "in" for "out" is profitable to begin with.
    function _findBestTradeSize(
        ISolidlyPair pair,
        address tokenIn,
        uint256 pIn,
        uint256 pOut,
        uint256 min
    ) private view returns (uint256 amountIn, uint256 amountOut) {
        // Crudely and inefficiently approach the optimum
        uint256 profit = 0;
        // Start with a smaller step size if tests overflow. Start with a
        // larger step size if results seem widely off
        for (uint256 step = min * 2**60; step >= min; step /= 2) {
            // Is increasing by `step` profitable at all?
            uint256 next = amountIn + step;
            uint256 nextOut = pair.getAmountOut(next, tokenIn);
            uint256 proceeds = pOut * nextOut;
            if (proceeds < pIn * next) {
                continue;
            }
            uint256 nextProfit = proceeds - pIn * next;
            if (nextProfit < profit) {
                continue;
            }

            // Is profit still increasing or have we passed the optimum?
            // uint256 next1 = next + min;
            uint256 proceeds1 = pOut * pair.getAmountOut(next + min, tokenIn);
            if (proceeds1 < pIn * (next + min)) {
                continue;
            }
            uint256 nextProfit1 = proceeds1 - pIn * (next + min);
            if (nextProfit1 < nextProfit) {
                continue;
            }

            amountIn = next;
            amountOut = nextOut;
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
