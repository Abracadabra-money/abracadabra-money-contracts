// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {BlastOnboarding} from "/blast/BlastOnboarding.sol";
import {BlastScript} from "script/Blast.s.sol";
import {ProxyOracle} from "oracles/ProxyOracle.sol";
import {CauldronDeployLib} from "utils/CauldronDeployLib.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {ICauldronV4} from "interfaces/ICauldronV4.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {InverseOracle} from "oracles/InverseOracle.sol";
import {IRedstoneAdapter, RedstoneAggregator} from "oracles/aggregators/RedstoneAggregator.sol";

contract BlastOnboardingScript is BaseScript {
    function deploy() public returns (BlastOnboarding onboarding) {
        BlastScript blastScript = new BlastScript();
        address safe = toolkit.getAddress(block.chainid, "safe.ops");
        address feeTo = safe;

        (, address blastTokenRegistry) = blastScript.deployPrerequisites(tx.origin, feeTo);

        vm.startBroadcast();
        onboarding = BlastOnboarding(
            payable(deploy("Onboarding", "BlastOnboarding.sol:BlastOnboarding", abi.encode(blastTokenRegistry, feeTo, tx.origin)))
        );

        // Depends on MIM  + Redstone
/*
        ProxyOracle oracle = ProxyOracle(deploy("WETH_Oracle", "ProxyOracle.sol:ProxyOracle", ""));
        bytes32 feedId = 0x4554480000000000000000000000000000000000000000000000000000000000; // eth feed id
        RedstoneAggregator redstoneAggregator = RedstoneAggregator(
            deploy(
                "WETH_RedstoneAggregator",
                "RedstoneAggregator.sol:RedstoneAggregator",
                abi.encode("WETH", IRedstoneAdapter(toolkit.getAddress(block.chainid, "redstone.adapter")), feedId)
            )
        );

        // redstone aggregator returns 8 decimals, upscale to 18
        InverseOracle inverseOracle = InverseOracle(
            deploy("WETH_InverseOracle", "InverseOracle.sol:InverseOracle", abi.encode("MIM/WETH", redstoneAggregator, 18))
        );

        if (oracle.oracleImplementation() != IOracle(address(inverseOracle))) {
            oracle.changeOracleImplementation(inverseOracle);
        }
*/
        if (!testing()) {
/*
            CauldronDeployLib.deployCauldronV4(
                "CauldronV4_WETH",
                IBentoBoxV1(toolkit.getAddress(ChainId.Blast, "degenBox")),
                toolkit.getAddress(ChainId.Blast, "cauldronV4"),
                IERC20(toolkit.getAddress(ChainId.Blast, "weth")),
                inverseOracle,
                "",
                8000, // 80% ltv
                600, // 6% interests
                50, // 0.5% opening
                600 // 6% liquidation
            );
*/
            address usdb = toolkit.getAddress(block.chainid, "usdb");
            //address mim = toolkit.getAddress(block.chainid, "mim");

            if (!onboarding.supportedTokens(usdb)) {
                onboarding.setTokenSupported(usdb, true);
            }
            //if (!onboarding.supportedTokens(mim)) {
            //    onboarding.setTokenSupported(mim, true);
            //}

            //if (oracle.owner() != safe) {
            //    oracle.transferOwnership(onboarding.owner());
            //}
        }

        vm.stopBroadcast();
    }
}
