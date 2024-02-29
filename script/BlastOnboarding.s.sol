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

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address,address)" "0x4C44B16422c4cd58a37aAD4Fc3b8b376393a91dC" "0x0451ADD899D63Ba6A070333550137c3e9691De7d" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3") \
                --compiler-version v0.8.20+commit.a1b79de6 0xa64B73699Cc7334810E382A4C09CAEc53636Ab96 src/blast/BlastOnboarding.sol:BlastOnboarding \
                --verifier-url https://api.blastscan.io/api \
                -e ${BLAST_ETHERSCAN_KEY}
        */
        onboarding = BlastOnboarding(
            payable(deploy("Onboarding", "BlastOnboarding.sol:BlastOnboarding", abi.encode(blastTokenRegistry, feeTo, tx.origin)))
        );

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --compiler-version v0.8.20+commit.a1b79de6 0x2612c7a5fDAF8Dea4f4D6C7A9da8e32A003706F6 src/oracles/ProxyOracle.sol:ProxyOracle \
                --verifier-url https://api.blastscan.io/api \
                -e ${BLAST_ETHERSCAN_KEY}
        */
        ProxyOracle oracle = ProxyOracle(deploy("WETH_Oracle", "ProxyOracle.sol:ProxyOracle", ""));
        bytes32 feedId = 0x4554480000000000000000000000000000000000000000000000000000000000; // eth feed id

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(string,address,bytes32)" "WETH" "0x0af23B08bcd8AD35D1e8e8f2D2B779024Bd8D24A" "0x4554480000000000000000000000000000000000000000000000000000000000") \
                --compiler-version v0.8.20+commit.a1b79de6 0x86e761F620b7ac8Ea373e0463C8c3BCCE7bD385B src/oracles/aggregators/RedstoneAggregator.sol:RedstoneAggregator \
                --verifier-url https://api.blastscan.io/api \
                -e ${BLAST_ETHERSCAN_KEY}
        */
        RedstoneAggregator redstoneAggregator = RedstoneAggregator(
            deploy(
                "WETH_RedstoneAggregator",
                "RedstoneAggregator.sol:RedstoneAggregator",
                abi.encode("WETH", IRedstoneAdapter(toolkit.getAddress(block.chainid, "redstone.adapter")), feedId)
            )
        );

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(string,address,uint8)" "MIM/WETH" "0x86e761F620b7ac8Ea373e0463C8c3BCCE7bD385B" 18) \
                --compiler-version v0.8.20+commit.a1b79de6 0xB2c3A9c577068479B1E5119f6B7da98d25Ba48f4 src/oracles/InverseOracle.sol:InverseOracle \
                --verifier-url https://api.blastscan.io/api \
                -e ${BLAST_ETHERSCAN_KEY}
        */
        // redstone aggregator returns 8 decimals, upscale to 18
        InverseOracle inverseOracle = InverseOracle(
            deploy("WETH_InverseOracle", "InverseOracle.sol:InverseOracle", abi.encode("MIM/WETH", redstoneAggregator, 18))
        );

        if (oracle.oracleImplementation() != IOracle(address(inverseOracle))) {
            oracle.changeOracleImplementation(inverseOracle);
        }

        if (!testing()) {
            address cauldron = address(
                CauldronDeployLib.deployCauldronV4(
                    "CauldronV4_WETH",
                    IBentoBoxV1(toolkit.getAddress(ChainId.Blast, "degenBox")),
                    toolkit.getAddress(ChainId.Blast, "cauldronV4"),
                    IERC20(toolkit.getAddress(ChainId.Blast, "weth")),
                    oracle,
                    "",
                    8000, // 80% ltv
                    600, // 6% interests
                    50, // 0.5% opening
                    600 // 6% liquidation
                )
            );

            require(IBlast(toolkit.getAddress(ChainId.Blast, "precompile.blast")).governorMap(cauldron) == blastGovernor, "wrong governor");

            address usdb = toolkit.getAddress(block.chainid, "usdb");
            address mim = toolkit.getAddress(block.chainid, "mim");
            if (!onboarding.supportedTokens(usdb)) {
                onboarding.setTokenSupported(usdb, true);
            }
            if (!onboarding.supportedTokens(mim)) {
                onboarding.setTokenSupported(mim, true);
            }
            if (onboarding.owner() != owner) {
                onboarding.transferOwnership(owner);
            }
            if (oracle.owner() != owner) {
                oracle.transferOwnership(onboarding.owner());
            }
        }

        vm.stopBroadcast();
    }
}
