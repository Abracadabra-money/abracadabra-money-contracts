// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "oracles/SolidlyStableOracle.sol";
import "utils/BaseTest.sol";
import "interfaces/IVelodromePairFactory.sol";
import "forge-std/console2.sol";

contract SolidlyStableOracleTest is BaseTest {
    ISolidlyPair[] pairs;

    function setUp() public override {
        super.setUp();
        forkOptimism(19570205);

        IVelodromePairFactory factory = IVelodromePairFactory(constants.getAddress("optimism.velodrome.factory"));
        uint256 count = factory.allPairsLength();
        for (uint256 i = 0; i < count; i++) {
            ISolidlyPair pair = factory.allPairs(i);
            if (pair.stable()) {
                pairs.push(pair);
            }
        }
        console2.log(pairs.length);
    }

    // tokenA chainlink oracle
    // tokenB chainlink oracle
    // pair reserves
    // list of velodrome stable pool
    // go to a block
    // get true pair price, (reserveA * tokenA price + reserverB * tokenB price) / totalSupply
    // display tokenA oracle and pool price in USD
    // display tokenB oracle and pool price in USD
    // deploy solidly stable oracle using velodrome pool + chainlink oracle
    // calculate deviation

    function test() public {
        
    }

    function xtestOracle1() public {
        ISolidlyPair pair = ISolidlyPair(ISolidlyPair(0xd16232ad60188B68076a235c65d692090caba155));
        IAggregator oracle0 = IAggregator(0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3); // USDC
        IAggregator oracle1 = IAggregator(0x7f99817d87baD03ea21E05112Ca799d715730efe); // SUSD

        SolidlyStableOracle oracle = new SolidlyStableOracle(pair, oracle0, oracle1);
        uint256 feed = uint256(oracle.latestAnswer());

        console2.log(feed);
    }

    function xtestOracle2() public {
        ISolidlyPair pair = ISolidlyPair(ISolidlyPair(0xFd7FddFc0A729eCF45fB6B12fA3B71A575E1966F));
        IAggregator oracle0 = IAggregator(0x13e3Ee699D1909E989722E753853AE30b17e08c5); // WETH
        IAggregator oracle1 = IAggregator(0x13e3Ee699D1909E989722E753853AE30b17e08c5); // SETH

        SolidlyStableOracle oracle = new SolidlyStableOracle(pair, oracle0, oracle1);
        uint256 feed = uint256(oracle.latestAnswer());

        console2.log(feed);
    }
}
