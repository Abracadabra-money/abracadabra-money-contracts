// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.8.0;

interface IPreCrimeView {
    struct Packet {
        uint16 srcChainId; // source chain id
        bytes32 srcAddress; // source UA address
        uint64 nonce;
        bytes payload;
    }

    struct SimulationResult {
        uint chainTotalSupply;
        bool isProxy;
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
    function precrime(Packet[] calldata _packets, bytes[] calldata _simulation) external view returns (uint16 code, bytes memory reason);

    /**
     * @dev protocol version
     */
    function version() external view returns (uint16);

    /**
     * @dev simulate run cross chain packets and get a simulation result for precrime later
     * @param _packets packets, the packets item should group by srcChainId, srcAddress, then sort by nonce
     * @return code   simulation result code; see the error code defination
     * @return result the result is use for precrime params
     */
    function simulate(Packet[] calldata _packets) external view returns (uint16 code, bytes memory result);
}
