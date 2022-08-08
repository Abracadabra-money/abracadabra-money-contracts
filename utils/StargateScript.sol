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
        address pool,
        address tokenOracle,
        string memory desc
    ) public returns (ProxyOracle proxy) {
        proxy = new ProxyOracle();
        StargateLPOracle oracle = new StargateLPOracle(IStargatePool(pool), IAggregator(tokenOracle), desc);
        proxy.changeOracleImplementation(IOracle(oracle));
    }

    function deployStargateLPStrategy(
        address collateral,
        address degenBox,
        address router,
        address staking,
        address rewardToken,
        uint256 pid
    ) public returns (StargateLPStrategy strategy) {
        strategy = new StargateLPStrategy(
            ERC20(collateral),
            IBentoBoxV1(degenBox),
            IStargateRouter(router),
            IStargateLPStaking(staking),
            ERC20(rewardToken),
            pid
        );
    }
    
    function deployStargateZeroExSwappers(
        address degenBox,
        address pool,
        uint16 poolId,
        address router,
        address mim,
        address zeroXExchangeProxy
    ) public returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        swapper = ISwapperV2(
            address(
                new ZeroXStargateLPSwapper(
                    IBentoBoxV1(degenBox),
                    IStargatePool(pool),
                    poolId,
                    IStargateRouter(router),
                    ERC20(mim),
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
                    ERC20(mim),
                    zeroXExchangeProxy
                )
            )
        );
    }

}
