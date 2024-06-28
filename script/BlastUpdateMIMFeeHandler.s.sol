// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {LzOFTV2FeeHandler} from "/periphery/LzOFTV2FeeHandler.sol";
import {BlastLzOFTV2FeeHandler, BlastLzOFTV2Wrapper} from "/blast/BlastLzOFTV2FeeHandler.sol";

contract BlastUpdateMIMFeeHandlerScript is BaseScript {
    uint16 constant ONE_PERCENT_BIPS = 100;

    function deploy() public returns (BlastLzOFTV2FeeHandler feeHandlerV2, BlastLzOFTV2Wrapper wrapper) {
        if (block.chainid != ChainId.Blast) {
            revert("not on Blast chain");
        }

        address safe = toolkit.getAddress("safe.ops", block.chainid);
        address safeYields = toolkit.getAddress("safe.yields", block.chainid);
        address blastGovernor = toolkit.getAddress(ChainId.Blast, "blastGovernor");
        address migrationBridge = 0xDa47C2662ce5773ec25c7C6Bfb149ec7bFEeE69D;

        LzOFTV2FeeHandler feehandlerV1 = LzOFTV2FeeHandler(payable(0x630FC1758De85C566Bdec1D75A894794E1819d7E));

        vm.startBroadcast();
        wrapper = BlastLzOFTV2Wrapper(
            payable(
                deploy(
                    "MIM_OFTWrapper",
                    "BlastLzOFTV2FeeHandler.sol:BlastLzOFTV2Wrapper",
                    abi.encode(feehandlerV1.oft(), tx.origin, blastGovernor)
                )
            )
        );

        feeHandlerV2 = BlastLzOFTV2FeeHandler(
            payable(
                deploy(
                    "MIM_FeeHandler_v2",
                    "BlastLzOFTV2FeeHandler.sol:BlastLzOFTV2FeeHandler",
                    abi.encode(
                        tx.origin,
                        feehandlerV1.fixedNativeFee(),
                        feehandlerV1.oft(),
                        feehandlerV1.aggregator(),
                        feehandlerV1.feeTo(),
                        feehandlerV1.quoteType(),
                        blastGovernor,
                        wrapper
                    )
                )
            )
        );

        wrapper.setFeeParameters(safeYields, ONE_PERCENT_BIPS);

        if (!feeHandlerV2.noTransitCheckWhitelist(migrationBridge)) {
            feeHandlerV2.setNoTransitCheckWhitelist(migrationBridge, true);
        }

        if (!feeHandlerV2.noTransitCheckWhitelist(safe)) {
            feeHandlerV2.setNoTransitCheckWhitelist(safe, true);
        }

        if (!wrapper.noFeeWhitelist(safe)) {
            wrapper.setNoFeeWhitelist(safe, true);
        }

        if (!feeHandlerV2.noTransitCheckWhitelist(safeYields)) {
            feeHandlerV2.setNoTransitCheckWhitelist(safeYields, true);
        }

        if (!wrapper.noFeeWhitelist(safeYields)) {
            wrapper.setNoFeeWhitelist(safeYields, true);
        }

        if (feeHandlerV2.owner() != safe) {
            feeHandlerV2.transferOwnership(safe);
        }

        if (wrapper.owner() != safe) {
            wrapper.transferOwnership(safe);
        }

        vm.stopBroadcast();
    }
}
