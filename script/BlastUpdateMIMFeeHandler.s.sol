// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {LzOFTV2FeeHandler} from "/periphery/LzOFTV2FeeHandler.sol";
import {BlastLzOFTV2FeeHandler} from "/blast/BlastLzOFTV2FeeHandler.sol";
import {BlastLzOFTV2Wrapper} from "/blast/BlastLzOFTV2Wrapper.sol";

contract BlastUpdateMIMFeeHandlerScript is BaseScript {
    uint16 constant ONE_PERCENT_BIPS = 100;

    function deploy() public returns (BlastLzOFTV2FeeHandler feeHandlerV2, BlastLzOFTV2Wrapper wrapper) {
        if (block.chainid != ChainId.Blast) {
            revert("not on Blast chain");
        }

        address safe = toolkit.getAddress("safe.ops");
        address safeYields = toolkit.getAddress("safe.yields");
        address blastGovernor = toolkit.getAddress("blastGovernor");

        LzOFTV2FeeHandler feehandlerV1 = LzOFTV2FeeHandler(payable(0x630FC1758De85C566Bdec1D75A894794E1819d7E));

        vm.startBroadcast();
        wrapper = BlastLzOFTV2Wrapper(
            payable(
                deploy(
                    "MIM_OFTWrapper",
                    "BlastLzOFTV2Wrapper.sol:BlastLzOFTV2Wrapper",
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

        if (!wrapper.noFeeWhitelist(safe)) {
            wrapper.setNoFeeWhitelist(safe, true);
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
