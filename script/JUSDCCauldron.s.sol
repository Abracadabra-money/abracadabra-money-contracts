// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {ERC20} from "BoringSolidity/ERC20.sol";
import {MagicJUSDC} from "tokens/MagicJUSDC.sol";
import {MagicJUSDCRewardHandler} from "periphery/MagicJUSDCRewardHandler.sol";
import {IMagicJUSDCRewardHandler} from "interfaces/IMagicJUSDCRewardHandler.sol";
import {MagicJUSDCHarvestor} from "periphery/MagicJUSDCHarvestor.sol";
import {MagicJUSDC} from "tokens/MagicJUSDC.sol";
import {IMiniChefV2} from "interfaces/IMiniChefV2.sol";
import {ProxyOracle} from "oracles/ProxyOracle.sol";
import {IOracle} from "interfaces/IOracle.sol";

contract JUSDCCauldronScript is BaseScript {
    function deploy() public {
        if (block.chainid != ChainId.Arbitrum) {
            revert("Unsupported chain");
        }

        address router = toolkit.getAddress(block.chainid, "jones.router");
        address jusdc = toolkit.getAddress(block.chainid, "jones.jusdc");
        //address box = toolkit.getAddress(block.chainid, "degenBox");
        address arb = toolkit.getAddress(block.chainid, "arb");
        address exchange = toolkit.getAddress(block.chainid, "aggregators.zeroXExchangeProxy");
        address feeTo = toolkit.getAddress(block.chainid, "safe.yields");

        vm.startBroadcast();
        deploy("MagicJUSDC", "MagicJUSDC.sol:MagicJUSDC", abi.encode(jusdc, "magicJUSDC", "mJUSDC"));

        MagicJUSDC mJUSDC = MagicJUSDC(
            payable(deploy("MagicJUSDC", "MagicJUSDC.sol:MagicJUSDC", abi.encode(jusdc, "magicJUSDC", "mJUSDC")))
        );
        IMagicJUSDCRewardHandler rewardHandler = IMagicJUSDCRewardHandler(
            deploy("MagicJUSDCRewardHandler", "MagicJUSDCRewardHandler.sol:MagicJUSDCRewardHandler", "")
        );

        if (mJUSDC.rewardHandler() != rewardHandler) {
            mJUSDC.setRewardHandler(rewardHandler);
        }

        IMiniChefV2 staking = IMiniChefV2(toolkit.getAddress(block.chainid, "jones.jusdcStaking"));
        (IMiniChefV2 currentStaking, ) = IMagicJUSDCRewardHandler(address(mJUSDC)).stakingInfo();

        if (currentStaking != staking) {
            IMagicJUSDCRewardHandler(address(mJUSDC)).setStaking(staking);
        }

        MagicJUSDCHarvestor harvestor = MagicJUSDCHarvestor(
            deploy("MagicJUSDCRewardHandler_Harvestor", "MagicJUSDCHarvestor.sol:MagicJUSDCHarvestor", abi.encode(mJUSDC, arb, router))
        );

        if (harvestor.exchangeRouter() != exchange) {
            harvestor.setExchangeRouter(exchange);
        }

        if (harvestor.feeCollector() != feeTo || harvestor.feeBips() != 100) {
            harvestor.setFeeParameters(feeTo, 100); // 1% fee
        }

        ProxyOracle oracle = ProxyOracle(deploy("MagicJUSDCProxyOracle", "ProxyOracle.sol:ProxyOracle", ""));
        address jusdcAggregator = deploy(
            "JUSDCAggregator",
            "JUSDCAggregator.sol:JUSDCAggregator",
            abi.encode(jusdc, toolkit.getAddress(block.chainid, "chainlink.usdc"))
        );
        IOracle impl = IOracle(deploy("MagicVaultOracle", "MagicVaultOracle.sol:MagicVaultOracle", abi.encode(mJUSDC, jusdcAggregator)));

        if (oracle.oracleImplementation() != impl) {
            oracle.changeOracleImplementation(impl);
        }

        _transferOwnershipsAndMintInitial(mJUSDC, harvestor, oracle);

        vm.stopBroadcast();
    }

    function _transferOwnershipsAndMintInitial(MagicJUSDC vault, MagicJUSDCHarvestor harvestor, ProxyOracle oracle) private {
        if (!testing()) {
            address safe = toolkit.getAddress(block.chainid, "safe.ops");

            if (oracle.owner() != safe) {
                oracle.transferOwnership(safe);
            }
            if (vault.owner() != safe) {
                vault.transferOwnership(safe, true, false);
            }

            if (!vault.operators(address(harvestor))) {
                vault.setOperator(address(harvestor), true);
            }

            if (vault.totalSupply() == 0) {
                address usdc = toolkit.getAddress(block.chainid, "usdc");

                // mint some initial tokens
                ERC20(usdc).approve(address(vault), 1.4269 * (10 ** 6));
                vault.deposit(1 ether, safe);
            }
        }
    }
}
