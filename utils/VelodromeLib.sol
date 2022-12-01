// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "periphery/VelodromeVolatileLpHarvester.sol";
import "tokens/SolidlyLpWrapper.sol";

library VelodromeLib {
    function deployWrappedLp(
        ISolidlyPair pair,
        ISolidlyRouter router,
        IVelodromePairFactory factory
    ) internal returns (SolidlyLpWrapper wrapper) {
        string memory name = string.concat("Abracadabra-", pair.name());
        string memory symbol = string.concat("Abra-", pair.name());
        uint8 decimals = pair.decimals();

        wrapper = new SolidlyLpWrapper(ISolidlyPair(pair), name, symbol, decimals);

        VelodromeVolatileLpHarvester harvester = new VelodromeVolatileLpHarvester(router, pair, factory);

        wrapper.setHarvester(harvester);
    }
}
