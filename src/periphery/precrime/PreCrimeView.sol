// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "interfaces/IPreCrimeView.sol";
import "periphery/precrime/PreCrimeBase.sol";

abstract contract PreCrimeView is PreCrimeBase, IPreCrimeView {
    /**
     * @dev 10000 - 20000 is for view mode, 20000 - 30000 is for precrime inherit mode
     */
    uint16 public constant PRECRIME_VERSION = 10001;

    constructor(uint16 _localChainId) PreCrimeBase(_localChainId) {}

    /**
     * @dev simulate run cross chain packets and get a simulation result for precrime later
     * @param _packets packets, the packets item should group by srcChainId, srcAddress, then sort by nonce
     * @return code   simulation result code; see the error code defination
     * @return data the result is use for precrime params
     */
    function simulate(Packet[] calldata _packets) external view override returns (uint16 code, bytes memory data) {
        // params check
        (code, data) = _checkPacketsMaxSizeAndNonceOrder(_packets);
        if (code != CODE_SUCCESS) {
            return (code, data);
        }

        (code, data) = _simulate(_packets);
        if (code == CODE_SUCCESS) {
            data = abi.encode(localChainId, data); // add localChainId to the header
        }
    }

    /**
     * @dev UA execute the logic by _packets, and return simulation result for precrime. would revert state after returned result.
     * @param _packets packets
     * @return code
     * @return result
     */
    function _simulate(Packet[] calldata _packets) internal view virtual returns (uint16 code, bytes memory result);

    function version() external pure override returns (uint16) {
        return PRECRIME_VERSION;
    }
}
