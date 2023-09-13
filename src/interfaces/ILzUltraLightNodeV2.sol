// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ILzUltraLightNodeV2 {
    function defaultAppConfig(
        uint16
    )
        external
        view
        returns (
            uint16 inboundProofLibraryVersion,
            uint64 inboundBlockConfirmations,
            address relayer,
            uint16 outboundProofType,
            uint64 outboundBlockConfirmations,
            address oracle
        );

    function appConfig(
        address,
        uint16
    )
        external
        view
        returns (
            uint16 inboundProofLibraryVersion,
            uint64 inboundBlockConfirmations,
            address relayer,
            uint16 outboundProofType,
            uint64 outboundBlockConfirmations,
            address oracle
        );
}
