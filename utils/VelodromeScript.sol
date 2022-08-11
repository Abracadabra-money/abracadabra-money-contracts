// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "harvesters/VelodromeVolatileLpHarvester.sol";
import "tokens/SolidlyLpWrapper.sol";

abstract contract VelodromeScript {
    function deployWrappedLp(
        ISolidlyPair pair,
        ISolidlyRouter router,
        IVelodromePairFactory factory
    ) public returns (SolidlyLpWrapper wrapper) {
        string memory name = string.concat(pair.name());
        string memory symbol = string.concat(pair.name());
        uint8 decimals = pair.decimals();

        wrapper = new SolidlyLpWrapper(ISolidlyPair(pair), name, symbol, decimals);

        VelodromeVolatileLpHarvester harvester = new VelodromeVolatileLpHarvester(router, pair, factory);

        wrapper.setHarvester(harvester);
    }
}
