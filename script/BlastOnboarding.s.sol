// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {BlastOnboarding} from "/blast/BlastOnboarding.sol";
import {ProxyOracle} from "oracles/ProxyOracle.sol";
import {CauldronDeployLib} from "utils/CauldronDeployLib.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {ICauldronV4} from "interfaces/ICauldronV4.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {InverseOracle} from "oracles/InverseOracle.sol";
import {IRedstoneAdapter, RedstoneAggregator} from "oracles/aggregators/RedstoneAggregator.sol";
import {IBlast} from "interfaces/IBlast.sol";
import {BlastYields} from "/blast/libraries/BlastYields.sol";

contract BlastOnboardingScript is BaseScript {
    function deploy() public returns (BlastOnboarding onboarding) {
        address owner = toolkit.getAddress(block.chainid, "safe.ops");
        address feeTo = toolkit.getAddress(block.chainid, "safe.ops");
        address blastGovernor = toolkit.getAddress(block.chainid, "blastGovernor");
        address blastTokenRegistry = toolkit.getAddress(block.chainid, "blastTokenRegistry");

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
            address cauldron = address(CauldronDeployLib.deployCauldronV4(
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
            ));

            require(IBlast(toolkit.getAddress(ChainId.Blast, "precompile.blast")).governorMap(cauldron) == blastGovernor, "wrong governor");
*/
            address usdb = toolkit.getAddress(block.chainid, "usdb");
            //address mim = toolkit.getAddress(block.chainid, "mim");

            if (!onboarding.supportedTokens(usdb)) {
                onboarding.setTokenSupported(usdb, true);
            }
            //if (!onboarding.supportedTokens(mim)) {
            //    onboarding.setTokenSupported(mim, true);
            //}
            //if(onboarding.owner() != owner) {
            //    onboarding.transferOwnership(owner);
            //}
            //if (oracle.owner() != safe) {
            //    oracle.transferOwnership(onboarding.owner());
            //}
        }

        vm.stopBroadcast();
    }
}
