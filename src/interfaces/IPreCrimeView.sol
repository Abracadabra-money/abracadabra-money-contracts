// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.8.0;

import "interfaces/IPreCrimeBase.sol";

interface IPreCrimeView is IPreCrimeBase {
    /**
     * @dev simulate run cross chain packets and get a simulation result for precrime later
     * @param _packets packets, the packets item should group by srcChainId, srcAddress, then sort by nonce
     * @return code   simulation result code; see the error code defination
     * @return result the result is use for precrime params
     */
    function simulate(Packet[] calldata _packets) external view returns (uint16 code, bytes memory result);
}
