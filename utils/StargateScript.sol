// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "swappers/ZeroXStargateLPSwapper.sol";
import "swappers/ZeroXStargateLPLevSwapper.sol";
import "oracles/ProxyOracle.sol";
import "oracles/StargateLPOracle.sol";
import "strategies/StargateLPStrategy.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/IStargatePool.sol";
import "interfaces/IStargateRouter.sol";
import "interfaces/IStargateLPStaking.sol";

abstract contract StargateScript  {
    function deployStargateLpOracle(
        IStargatePool pool,
        IAggregator tokenOracle,
        string memory desc
    ) public returns (ProxyOracle proxy) {
        proxy = new ProxyOracle();
        StargateLPOracle oracle = new StargateLPOracle(pool, tokenOracle, desc);
        proxy.changeOracleImplementation(IOracle(oracle));
    }

    function deployStargateLPStrategy(
        IStargatePool collateral,
        IBentoBoxV1 degenBox,
        IStargateRouter router,
        IStargateLPStaking staking,
        IERC20 rewardToken,
        uint256 pid
    ) public returns (StargateLPStrategy strategy) {
        strategy = new StargateLPStrategy(
            collateral,
            degenBox,
            router,
            staking,
            rewardToken,
            pid
        );
    }
    
    function deployStargateZeroExSwappers(
        IBentoBoxV1 degenBox,
        IStargatePool pool,
        uint16 poolId,
        IStargateRouter router,
        IERC20 mim,
        address zeroXExchangeProxy
    ) public returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        swapper = ISwapperV2(
            address(
                new ZeroXStargateLPSwapper(
                    degenBox,
                    pool,
                    poolId,
                    router,
                    mim,
                    zeroXExchangeProxy
                )
            )
        );
        levSwapper = ILevSwapperV2(
            address(
                new ZeroXStargateLPLevSwapper(
                    IBentoBoxV1(degenBox),
                    IStargatePool(pool),
                    poolId,
                    IStargateRouter(router),
                    IERC20(mim),
                    zeroXExchangeProxy
                )
            )
        );
    }

}
