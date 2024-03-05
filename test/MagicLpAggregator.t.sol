// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "oracles/aggregators/MagicLpAggregator.sol";

// import "forge-std/console2.sol";

interface IDodo {
    function getVaultReserve() external view returns (uint256 baseReserve, uint256 quoteReserve);
}

contract MagicLpAggregatorExt is MagicLpAggregator {

    constructor(
        IMagicLP pair_,
        IAggregator baseOracle_,
        IAggregator quoteOracle_
    ) MagicLpAggregator(pair_, baseOracle_, quoteOracle_) {}

    function _getReserves() internal view override returns (uint256, uint256) {
        return IDodo(address(pair)).getVaultReserve();
    }

}

contract MagicLpAggregatorTest is BaseTest {
    MagicLpAggregatorExt aggregator;

    function setUp() public override {
        fork(ChainId.Mainnet, 19365773);
        _setUp();
    }

    function _setUp() public {
        super.setUp();

        aggregator = new MagicLpAggregatorExt(
            IMagicLP(0x3058EF90929cb8180174D74C507176ccA6835D73),
            IAggregator(0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9),
            IAggregator(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D)
        );
    }

    function testGetResult() public {
        uint256 response = uint256(aggregator.latestAnswer());
        assertEq(response, 2000502847471294054);
    }
}
