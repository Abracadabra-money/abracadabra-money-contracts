// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "/oracles/aggregators/MagicLpAggregator.sol";
import {MagicLpAggregator} from "/oracles/aggregators/MagicLpAggregator.sol";
import {console2} from "forge-std/console2.sol";
import {MagicLP} from "/mimswap/MagicLP.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {FeeRateModel} from "/mimswap/auxiliary/FeeRateModel.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {IFeeRateModel} from "/mimswap/interfaces/IFeeRateModel.sol";
import {IFactory} from "/mimswap/interfaces/IFactory.sol";
import {IMagicLP} from "/mimswap/interfaces/IMagicLP.sol";
import {IWETH} from "/interfaces/IWETH.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";
import {Factory} from "/mimswap/periphery/Factory.sol";
import {PMMPricing} from "/mimswap/libraries/PMMPricing.sol";
import {Router} from "/mimswap/periphery/Router.sol";
import {MagicLPLens} from "/lenses/MagicLPLens.sol";

contract MagicLpAggregatorForkTest is BaseTest {
    function setUp() public override {
        fork(ChainId.Mainnet, 19365773);
        super.setUp();
    }

    function testDAIUSDT() public {
        MagicLpAggregator aggregator = new MagicLpAggregator(
            IMagicLP(0x3058EF90929cb8180174D74C507176ccA6835D73),
            IAggregator(0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9),
            IAggregator(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D)
        );
        uint256 response = uint256(aggregator.latestAnswer());
        assertApproxEqRel(response, 2000502847471294054, 0.001 ether);
    }
}

contract MockPriceAggregator is IAggregator {
    int256 public latestAnswer;
    uint8 public decimals;

    constructor(int256 _price, uint8 _decimals) {
        latestAnswer = _price;
        decimals = _decimals;
    }

    function setPrice(int256 _price) public {
        latestAnswer = _price;
    }

    function setDecimals(uint8 _decimals) public {
        decimals = _decimals;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, latestAnswer, 0, 0, 0);
    }
}

contract MagicLpAggregatorTest is BaseTest {
    using FixedPointMathLib for uint256;

    uint256 constant MIN_LP_FEE_RATE = 1e14;

    ERC20Mock baseToken;
    ERC20Mock quoteToken;

    MagicLP lp;
    MagicLP clone;

    FeeRateModel maintainerFeeRateModel;
    address registryOwner;

    address authorizedCreator;

    address factoryOwner;
    address maintainer;
    Factory factory;

    Router router;

    MagicLPLens lens;

    function setUp() public override {
        super.setUp();

        maintainer = makeAddr("Maintainer");
        factoryOwner = makeAddr("FactoryOwner");
        authorizedCreator = makeAddr("AuthorizedCreator");

        baseToken = new ERC20Mock("BaseToken", "BaseToken");
        quoteToken = new ERC20Mock("QuoteToken", "QuoteToken");

        lp = new MagicLP(address(this));
        maintainerFeeRateModel = new FeeRateModel(maintainer, address(0));
        factory = new Factory(address(lp), IFeeRateModel(address(maintainerFeeRateModel)), factoryOwner);

        router = new Router(IWETH(makeAddr("WETH")), IFactory(address(factory)));
        lens = new MagicLPLens();
    }

    function testVolatile() public {
        baseToken.mint(address(this), 10 ether);
        quoteToken.mint(address(this), 600000 ether);
        baseToken.approve(address(router), 10 ether);
        quoteToken.approve(address(router), 600000 ether);
        (address cloneAddress, ) = router.createPool(
            address(baseToken),
            address(quoteToken),
            MIN_LP_FEE_RATE,
            60000 ether,
            1 ether,
            address(this),
            10 ether,
            600000 ether,
            false
        );
        clone = MagicLP(cloneAddress);

        MockPriceAggregator basePriceAggregator = new MockPriceAggregator(60000 ether, 18);
        MockPriceAggregator quotePriceAggregator = new MockPriceAggregator(1 ether, 18);
        MagicLpAggregator aggregator = new MagicLpAggregator(IMagicLP(cloneAddress), basePriceAggregator, quotePriceAggregator);

        (uint256 baseReserve, uint256 quoteReserve) = clone.getReserves();
        assertApproxEqRel(
            (baseReserve.mulWad(uint256(basePriceAggregator.latestAnswer())) +
                quoteReserve.mulWad(uint256(quotePriceAggregator.latestAnswer()))).divWad(clone.totalSupply()),
            uint256(aggregator.latestAnswer()),
            1e4
        );

        baseToken.mint(cloneAddress, 1 ether);
        clone.sellBase(address(this));
        basePriceAggregator.setPrice(int256(lens.getMidPrice(cloneAddress)));

        (baseReserve, quoteReserve) = clone.getReserves();
        assertApproxEqRel(
            (baseReserve.mulWad(uint256(basePriceAggregator.latestAnswer())) +
                quoteReserve.mulWad(uint256(quotePriceAggregator.latestAnswer()))).divWad(clone.totalSupply()),
            uint256(aggregator.latestAnswer()),
            1e4
        );

        quoteToken.mint(cloneAddress, 120000 ether);
        clone.sellQuote(address(this));
        basePriceAggregator.setPrice(int256(lens.getMidPrice(cloneAddress)));
        (baseReserve, quoteReserve) = clone.getReserves();
        assertApproxEqRel(
            (baseReserve.mulWad(uint256(basePriceAggregator.latestAnswer())) +
                quoteReserve.mulWad(uint256(quotePriceAggregator.latestAnswer()))).divWad(clone.totalSupply()),
            uint256(aggregator.latestAnswer()),
            1e4
        );
    }

    function testSwapsPrice(
        uint256 baseDepositAmount,
        uint256 quoteDepositAmount,
        uint256 k,
        uint256 sellBaseAmount,
        uint256 sellQuoteAmount
    ) public {
        baseDepositAmount = bound(baseDepositAmount, 1 ether, type(uint64).max);
        quoteDepositAmount = bound(quoteDepositAmount, 1 ether, type(uint64).max);
        k = bound(quoteDepositAmount, 1e6, 1 ether);
        sellBaseAmount = bound(sellBaseAmount, 1 ether, type(uint64).max);
        sellQuoteAmount = bound(sellQuoteAmount, 1 ether, type(uint64).max);

        baseToken.mint(address(this), baseDepositAmount);
        quoteToken.mint(address(this), quoteDepositAmount);
        baseToken.approve(address(router), baseDepositAmount);
        quoteToken.approve(address(router), quoteDepositAmount);
        uint256 i = quoteDepositAmount.divWad(baseDepositAmount);
        try
            router.createPool(
                address(baseToken),
                address(quoteToken),
                MIN_LP_FEE_RATE,
                i,
                k,
                address(this),
                baseDepositAmount,
                quoteDepositAmount,
                false
            )
        returns (address cloneAddress, uint256) {
            clone = MagicLP(cloneAddress);
        } catch {
            vm.assume(false);
        }

        baseToken.mint(address(clone), sellBaseAmount);
        try clone.sellBase(address(this)) {} catch {
            vm.assume(false);
        }
        quoteToken.mint(address(clone), sellQuoteAmount);
        try clone.sellQuote(address(this)) {} catch {
            vm.assume(false);
        }

        PMMPricing.PMMState memory pmmState = clone.getPMMState();
        console2.log(pmmState.B, pmmState.Q, pmmState.B0, pmmState.Q0);

        MockPriceAggregator basePriceAggregator;
        try lens.getMidPrice(address(clone)) returns (uint256 price) {
            basePriceAggregator = new MockPriceAggregator(int256(price), 18);
        } catch {
            vm.assume(false);
        }
        MockPriceAggregator quotePriceAggregator = new MockPriceAggregator(1 ether, 18);
        vm.assume(uint256(k).mulWad(uint256(basePriceAggregator.latestAnswer())) > 1e8);
        MagicLpAggregator aggregator = new MagicLpAggregator(IMagicLP(address(clone)), basePriceAggregator, quotePriceAggregator);

        (uint256 baseReserve, uint256 quoteReserve) = clone.getReserves();
        assertApproxEqRel(
            (baseReserve.mulWad(uint256(basePriceAggregator.latestAnswer())) +
                quoteReserve.mulWad(uint256(quotePriceAggregator.latestAnswer()))).divWad(clone.totalSupply()),
            uint256(aggregator.latestAnswer()),
            0.01 ether
        );
    }

    function test_poc_inflate_lp_price() public {
        baseToken.mint(address(this), 10 ether);
        quoteToken.mint(address(this), 600000 ether);
        baseToken.approve(address(router), 10 ether);
        quoteToken.approve(address(router), 600000 ether);

        (address cloneAddress, ) = router.createPool(
            address(baseToken),
            address(quoteToken),
            MIN_LP_FEE_RATE,
            60000 ether,
            1 ether,
            address(this),
            10 ether,
            600000 ether,
            false
        );
        clone = MagicLP(cloneAddress);
        uint shareBalAfter = clone.balanceOf(address(this));
        assertEq(shareBalAfter, clone.totalSupply() - 1001);

        MockPriceAggregator basePriceAggregator = new MockPriceAggregator(60000 ether, 18);
        MockPriceAggregator quotePriceAggregator = new MockPriceAggregator(1 ether, 18);
        MagicLpAggregator aggregator = new MagicLpAggregator(IMagicLP(cloneAddress), basePriceAggregator, quotePriceAggregator);

        console2.log();
        console2.log("################ ANSWER AFTER LIQUIDITY ADDED ######################");
        basePriceAggregator.setPrice(int256(lens.getMidPrice(cloneAddress)));
        console2.log("<magiclp> base reserve #0:", clone._BASE_RESERVE_());
        console2.log("<magiclp> quote reserve #0:", clone._QUOTE_RESERVE_());
        console2.log("<test latest answer> #0 uint256(aggregator.latestAnswer()):", uint256(aggregator.latestAnswer()));
        console2.log("######################################");

        console2.log();
        console2.log("################ SELL ALL AVAILABLE SHARES ######################");
        clone.sellShares(shareBalAfter, address(this), 0, 0, "", type(uint256).max);
        basePriceAggregator.setPrice(int256(lens.getMidPrice(cloneAddress)));
        console2.log("<magiclp> midprice #1:", int256(lens.getMidPrice(cloneAddress)));
        console2.log("<magiclp> base reserve #1:", clone._BASE_RESERVE_());
        console2.log("<magiclp> quote reserve #1:", clone._QUOTE_RESERVE_());
        console2.log("<test latest answer> #1 uint256(aggregator.latestAnswer()):", uint256(aggregator.latestAnswer()));
        console2.log("######################################");

        console2.log();
        console2.log("################ BUY MORE SHARES ######################");
        quoteToken.mint(cloneAddress, 1e18);
        baseToken.mint(cloneAddress, 1e18);
        clone.buyShares(address(this));
        console2.log("<magiclp> midprice #2:", int256(lens.getMidPrice(cloneAddress)));
        console2.log("<magiclp> base reserve #2:", clone._BASE_RESERVE_());
        console2.log("<magiclp> quote reserve #2:", clone._QUOTE_RESERVE_());
        // basePriceAggregator.setPrice(int256(lens.getMidPrice(cloneAddress)));
        uint answerBeforeSale = uint256(aggregator.latestAnswer());
        console2.log("<test latest answer> #2 uint256(aggregator.latestAnswer()):", uint256(aggregator.latestAnswer()));
        console2.log("######################################");

        console2.log();
        console2.log("################### SELL SOME BASE TOKEN ###################");
        baseToken.mint(cloneAddress, 1e12);
        clone.sellBase(address(this));
        // basePriceAggregator.setPrice(int256(lens.getMidPrice(cloneAddress)));
        uint answerAfterSale = uint256(aggregator.latestAnswer());
        console2.log("<test latest answer> #3 uint256(aggregator.latestAnswer()):", uint256(aggregator.latestAnswer()));
        console2.log("######################################");

        assertApproxEqRel(answerAfterSale, answerBeforeSale, 0.0000000001 ether);
    }

    function test_poc_aggregator_dos_cleaned() public {
        uint baseDepositAmount = 1e18;
        uint quoteDepositAmount = 3e18;
        uint k = 1 ether;
        uint sellBaseAmount = 0.1e18;
        uint sellQuoteAmount = 0.1e18;

        baseToken.mint(address(this), baseDepositAmount);
        quoteToken.mint(address(this), quoteDepositAmount);
        baseToken.approve(address(router), baseDepositAmount);
        quoteToken.approve(address(router), quoteDepositAmount);
        uint256 i = uint256(baseDepositAmount).divWad(quoteDepositAmount);
        try
            router.createPool(
                address(baseToken),
                address(quoteToken),
                MIN_LP_FEE_RATE,
                i,
                k,
                address(this),
                baseDepositAmount,
                quoteDepositAmount,
                false
            )
        returns (address cloneAddress, uint256) {
            clone = MagicLP(cloneAddress);
        } catch {
            vm.assume(false);
        }

        baseToken.mint(address(clone), sellBaseAmount);
        try clone.sellBase(address(this)) {} catch {
            vm.assume(false);
        }

        quoteToken.mint(address(clone), sellQuoteAmount);
        try clone.sellQuote(address(this)) {} catch {
            vm.assume(false);
        }

        PMMPricing.PMMState memory pmmState = clone.getPMMState();
        console2.log(pmmState.B, pmmState.Q, pmmState.B0, pmmState.Q0);

        MockPriceAggregator basePriceAggregator;
        try lens.getMidPrice(address(clone)) returns (uint256 price) {
            basePriceAggregator = new MockPriceAggregator(int256(price), 18);
        } catch {
            vm.assume(false);
        }

        MockPriceAggregator quotePriceAggregator = new MockPriceAggregator(1 ether, 18);
        vm.assume(uint256(k).mulWad(uint256(basePriceAggregator.latestAnswer())) > 1e8);
        MagicLpAggregator aggregator = new MagicLpAggregator(IMagicLP(address(clone)), basePriceAggregator, quotePriceAggregator);

        aggregator.latestAnswer();
    }
}
