// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "strategies/NegativeInterestStrategy.sol";
import "libraries/CauldronLib.sol";

contract NegativeInterestStrategyScript is BaseScript {
    using DeployerFunctions for Deployer;

    function deploy() public {
        uint64 defaultInterest = CauldronLib.getInterestPerSecond(2000); // 20%

        if (block.chainid == ChainId.Mainnet) {
            address safe = toolkit.getAddress(block.chainid, "safe.ops");
            address gelatoProxy = toolkit.getAddress(block.chainid, "safe.devOps.gelatoProxy");

            NegativeInterestStrategy strategy = deployer.deploy_NegativeInterestStrategy(
                "Mainnet_CRV_NegativeInterestStrategy",
                IERC20(toolkit.getAddress(block.chainid, "crv")),
                IERC20(toolkit.getAddress(ChainId.Mainnet, "mim")),
                IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox")),
                safe
            );

            if (strategy.interestPerSecond() != defaultInterest) {
                vm.broadcast();
                strategy.setInterestPerSecond(defaultInterest);
            }

            if (!strategy.strategyExecutors(gelatoProxy)) {
                vm.broadcast();
                strategy.setStrategyExecutor(gelatoProxy, true);
            }

            if (strategy.owner() != safe) {
                vm.broadcast();
                strategy.transferOwnership(safe, true, false);
            }
        }
    }
}
