// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "utils/CauldronDeployLib.sol";
import "oracles/ProxyOracle.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/ICauldronV4.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IAggregator.sol";
import "strategies/StargateLPStrategy.sol";

contract StargateLpCauldronScript is BaseScript {
    using DeployerFunctions for Deployer;

    IBentoBoxV1 box;
    address safe;
    IStargatePool pool;
    IStargateRouter router;
    IStargateLPStaking staking;
    address rewardToken;
    address exchange;

    function deploy() public returns (StargateLPStrategy strategy) {
        if (block.chainid == ChainId.Kava) {
            return _deployKavaStargateLPUSDT();
        } else {
            revert("Unsupported chain");
        }
    }

    function _deployKavaStargateLPUSDT() private returns (StargateLPStrategy strategy) {
        pool = IStargatePool(toolkit.getAddress(block.chainid, "stargate.usdtPool"));
        router = IStargateRouter(toolkit.getAddress(block.chainid, "stargate.router"));
        staking = IStargateLPStaking(toolkit.getAddress(block.chainid, "stargate.staking"));
        rewardToken = toolkit.getAddress(block.chainid, "wKava");
        safe = toolkit.getAddress(block.chainid, "safe.ops");
        box = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        exchange = toolkit.getAddress(block.chainid, "aggregators.openocean");

        // USDT Pool
        strategy = deployer.deploy_StargateLPStrategy(
            toolkit.prefixWithChainName(block.chainid, "StargateLPStrategy"),
            pool,
            box,
            router,
            staking,
            rewardToken,
            0
        );

        vm.broadcast();
        strategy.setStargateSwapper(exchange);
    }
}
