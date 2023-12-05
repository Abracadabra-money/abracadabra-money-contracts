// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {GmStrategy} from "strategies/GmStrategy.sol";
import {PrivateMultiRewardsStaking} from "periphery/MultiRewardsStaking.sol";

contract GmStrategyScript is BaseScript {
    address degenBox;
    address exchangeRouter;
    address reader;
    address syntheticsRouter;
    address safe;
    address usdc;
    address arb;
    address gelatoProxy;
    address zeroXAggregator;

    function deploy() public {
        vm.startBroadcast();

        if (block.chainid != ChainId.Arbitrum) {
            revert("Only Arbitrum");
        }

        degenBox = toolkit.getAddress(block.chainid, "DegenBox");
        exchangeRouter = toolkit.getAddress(block.chainid, "gmx.v2.exchangeRouter");
        reader = toolkit.getAddress(block.chainid, "gmx.v2.reader");
        syntheticsRouter = toolkit.getAddress(block.chainid, "gmx.v2.syntheticsRouter");
        safe = toolkit.getAddress(block.chainid, "safe.ops");
        usdc = toolkit.getAddress(block.chainid, "usdc");
        arb = toolkit.getAddress(block.chainid, "arb");
        gelatoProxy = toolkit.getAddress(block.chainid, "safe.devOps.gelatoProxy");
        zeroXAggregator = toolkit.getAddress(block.chainid, "aggregators.zeroXExchangeProxy");

        _deployMarketStrategy("GmARB", toolkit.getAddress(block.chainid, "gmx.v2.gmARB"), arb, usdc);
        _deployMarketStrategy("GmETH", toolkit.getAddress(block.chainid, "gmx.v2.gmETH"), usdc, address(0));
        _deployMarketStrategy("GmBTC", toolkit.getAddress(block.chainid, "gmx.v2.gmBTW"), usdc, address(0));
        _deployMarketStrategy("GmSOL", toolkit.getAddress(block.chainid, "gmx.v2.gmSOL"), usdc, address(0));

        vm.stopBroadcast();
    }

    function _deployMarketStrategy(string memory name, address market, address marketInputToken, address marketInputToken2) private {
        require(marketInputToken != address(0), "invalid marketInputToken");
        require(market != address(0), "invalid market");

        PrivateMultiRewardsStaking staking = PrivateMultiRewardsStaking(
            deploy(
                string.concat(name, "_Strategy_Staking"),
                "MultiRewardsStaking.sol:PrivateMultiRewardsStaking",
                abi.encode(market, tx.origin)
            )
        );

        GmStrategy strategy = GmStrategy(
            payable(
                deploy(
                    string.concat(name, "_Strategy"),
                    "GmStrategy.sol:GmStrategy",
                    abi.encode(market, degenBox, exchangeRouter, reader, syntheticsRouter, safe, staking)
                )
            )
        );

        strategy.setExchange(zeroXAggregator);
        staking.addReward(arb, 7 days);
        staking.setAuthorized(address(strategy), true);

        strategy.setStrategyExecutor(gelatoProxy, true);
        strategy.setTokenApproval(marketInputToken, zeroXAggregator, type(uint256).max);
        strategy.setTokenApproval(marketInputToken, syntheticsRouter, type(uint256).max);

        if (marketInputToken2 != address(0)) {
            strategy.setTokenApproval(marketInputToken2, syntheticsRouter, type(uint256).max);
        }

        if (!testing()) {
            strategy.transferOwnership(safe, true, false);
            staking.transferOwnership(safe);
        }
    }
}
