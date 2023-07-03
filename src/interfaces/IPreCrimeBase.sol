// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.7.0;
pragma abicoder v2;

interface IPreCrimeBase {
    struct Packet {
        uint16 srcChainId; // source chain id
        bytes32 srcAddress; // srouce UA address
        uint64 nonce;
        bytes payload;
    }

    /**
     * @dev get precrime config,
     * @param _packets packets
     * @return bytes of [maxBatchSize, remotePrecrimes]
     */
    function getConfig(Packet[] calldata _packets) external view returns (bytes memory);

    /**
     * @dev
     * @param _simulation all simulation results from difference chains
     * @return code     precrime result code; check out the error code defination
     * @return reason   error reason
     */
    function precrime(
        Packet[] calldata _packets,
        bytes[] calldata _simulation
    ) external view returns (uint16 code, bytes memory reason);

    /**
     * @dev protocol version
     */
    function version() external view returns (uint16);
}
