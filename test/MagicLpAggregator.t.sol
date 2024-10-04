// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "/oracles/aggregators/MagicLpAggregator.sol";
import {MagicLP} from "/mimswap/MagicLP.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {FeeRateModel} from "/mimswap/auxiliary/FeeRateModel.sol";
import {IFeeRateModel} from "/mimswap/interfaces/IFeeRateModel.sol";
import {IFactory} from "/mimswap/interfaces/IFactory.sol";
import {IWETH} from "/interfaces/IWETH.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";
import {Factory} from "/mimswap/periphery/Factory.sol";
import {Router} from "/mimswap/periphery/Router.sol";
import {MagicLPLens} from "/lenses/MagicLPLens.sol";

contract MagicLpAggregatorForkTest is BaseTest {
    function setUp() public override {
        fork(ChainId.Mainnet, 19365773);
        super.setUp();
    }

    function testMIMDAI() public {
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
            1e14
        );

        baseToken.mint(cloneAddress, 1 ether);
        clone.sellBase(address(this));
        basePriceAggregator.setPrice(int256(lens.getMidPrice(cloneAddress)));

        (baseReserve, quoteReserve) = clone.getReserves();
        assertApproxEqRel(
            (baseReserve.mulWad(uint256(basePriceAggregator.latestAnswer())) +
                quoteReserve.mulWad(uint256(quotePriceAggregator.latestAnswer()))).divWad(clone.totalSupply()),
            uint256(aggregator.latestAnswer()),
            1e14
        );

        quoteToken.mint(cloneAddress, 120000 ether);
        clone.sellQuote(address(this));
        basePriceAggregator.setPrice(int256(lens.getMidPrice(cloneAddress)));
        (baseReserve, quoteReserve) = clone.getReserves();
        assertApproxEqRel(
            (baseReserve.mulWad(uint256(basePriceAggregator.latestAnswer())) +
                quoteReserve.mulWad(uint256(quotePriceAggregator.latestAnswer()))).divWad(clone.totalSupply()),
            uint256(aggregator.latestAnswer()),
            1e14
        );

        // console2.log("price:", toolkit.formatDecimals(uint256(aggregator.latestAnswer())));
        // console2.log(
        //     "actual price",
        //     toolkit.formatDecimals(
        //     )
        // );
    }
}
