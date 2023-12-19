// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IOFTV2View, IPreCrimeView} from "interfaces/ILayerZero.sol";
import {Owned} from "solmate/auth/Owned.sol";

contract PreCrimeView is IPreCrimeView, Owned {
    error ErrInvalidSize();

    uint16 public constant CONFIG_VERSION = 1;

    //---------------- error code ----------------------
    // --- UA scope code ---
    uint16 public constant CODE_SUCCESS = 0; // success
    uint16 public constant CODE_PRECRIME_FAILURE = 1; // !!! crimes found

    // --- protocol scope error code ---
    // simualte
    uint16 public constant CODE_PACKETS_OVERSIZE = 2; // packets number bigger then max size
    uint16 public constant CODE_PACKETS_UNSORTED = 3; // packets are unsorted, need backfill and keep order
    // precrime
    uint16 public constant CODE_MISS_SIMULATE_RESULT = 4; // miss simulation result

    /**
     * @dev 10000 - 20000 is for view mode, 20000 - 30000 is for precrime inherit mode
     */
    uint16 public constant PRECRIME_VERSION = 10001;

    /// @notice a view for OFTV2 or ProxyOFTV2
    IOFTV2View public immutable oftView;

    uint16 public localChainId;
    uint16[] public remoteChainIds;
    bytes32[] public remotePrecrimeAddresses;
    uint64 public maxBatchSize;

    constructor(address _owner, uint16 _localChainId, address _oftView, uint64 _maxSize) Owned(_owner) {
        localChainId = _localChainId;
        oftView = IOFTV2View(_oftView);
        maxBatchSize = _maxSize;
    }

    function setRemotePrecrimeAddresses(uint16[] memory _remoteChainIds, bytes32[] memory _remotePrecrimeAddresses) public onlyOwner {
        if (_remoteChainIds.length != _remotePrecrimeAddresses.length) {
            revert ErrInvalidSize();
        }

        remoteChainIds = _remoteChainIds;
        remotePrecrimeAddresses = _remotePrecrimeAddresses;
    }

    function setMaxBatchSize(uint64 _maxSize) public onlyOwner {
        maxBatchSize = _maxSize;
    }

    /**
     * @dev get precrime config,
     * @param _packets packets
     * @return configation bytes
     */
    function getConfig(Packet[] calldata _packets) external view virtual override returns (bytes memory) {
        (uint16[] memory remoteChains, bytes32[] memory remoteAddresses) = _remotePrecrimeAddress(_packets);
        return
            abi.encodePacked(
                CONFIG_VERSION,
                //---- max packets size for simulate batch ---
                _maxBatchSize(),
                //------------- remote precrimes -------------
                remoteChains.length,
                remoteChains,
                remoteAddresses
            );
    }

    /**
     * @dev
     * @param _simulation all simulation results from difference chains
     * @return code     precrime result code; check out the error code definition
     * @return reason   error reason
     */
    function precrime(
        Packet[] calldata _packets,
        bytes[] calldata _simulation
    ) external view override returns (uint16 code, bytes memory reason) {
        bytes[] memory originSimulateResult = new bytes[](_simulation.length);
        uint16[] memory chainIds = new uint16[](_simulation.length);
        for (uint256 i = 0; i < _simulation.length; i++) {
            (uint16 chainId, bytes memory simulateResult) = abi.decode(_simulation[i], (uint16, bytes));
            chainIds[i] = chainId;
            originSimulateResult[i] = simulateResult;
        }

        (code, reason) = _checkResultsCompleteness(_packets, chainIds);
        if (code != CODE_SUCCESS) {
            return (code, reason);
        }

        (code, reason) = _precrime(originSimulateResult);
    }

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

    function version() external pure override returns (uint16) {
        return PRECRIME_VERSION;
    }

    function _checkPacketsMaxSizeAndNonceOrder(Packet[] calldata _packets) internal view returns (uint16 code, bytes memory reason) {
        uint64 maxSize = _maxBatchSize();
        if (_packets.length > maxSize) {
            return (CODE_PACKETS_OVERSIZE, abi.encodePacked("packets size exceed limited"));
        }

        // check packets nonce, sequence order
        // packets should group by srcChainId and srcAddress, then sort by nonce ascending
        if (_packets.length > 0) {
            uint16 srcChainId;
            bytes32 srcAddress;
            uint64 nonce;
            for (uint256 i = 0; i < _packets.length; i++) {
                Packet memory packet = _packets[i];
                // start from a new chain packet or a new source UA
                if (packet.srcChainId != srcChainId || packet.srcAddress != srcAddress) {
                    srcChainId = packet.srcChainId;
                    srcAddress = packet.srcAddress;
                    nonce = packet.nonce;
                    uint64 nextInboundNonce = _getInboundNonce(packet) + 1;
                    // the first packet's nonce must equal to dst InboundNonce+1
                    if (nonce != nextInboundNonce) {
                        return (CODE_PACKETS_UNSORTED, abi.encodePacked("skipped inboundNonce forbidden"));
                    }
                } else {
                    // the following packet's nonce add 1 in order
                    if (packet.nonce != ++nonce) {
                        return (CODE_PACKETS_UNSORTED, abi.encodePacked("unsorted packets"));
                    }
                }
            }
        }
        return (CODE_SUCCESS, "");
    }

    function _checkResultsCompleteness(
        Packet[] calldata _packets,
        uint16[] memory _resultChainIds
    ) internal view returns (uint16 code, bytes memory reason) {
        // check if all remote result included
        if (_packets.length > 0) {
            (uint16[] memory remoteChains, ) = _remotePrecrimeAddress(_packets);
            for (uint256 i = 0; i < remoteChains.length; i++) {
                bool resultChainIdChecked;
                for (uint256 j = 0; j < _resultChainIds.length; j++) {
                    if (_resultChainIds[j] == remoteChains[i]) {
                        resultChainIdChecked = true;
                        break;
                    }
                }
                if (!resultChainIdChecked) {
                    return (CODE_MISS_SIMULATE_RESULT, "missing remote simulation result");
                }
            }
        }
        // check if local result included
        bool localChainIdResultChecked;
        for (uint256 j = 0; j < _resultChainIds.length; j++) {
            if (_resultChainIds[j] == localChainId) {
                localChainIdResultChecked = true;
                break;
            }
        }
        if (!localChainIdResultChecked) {
            return (CODE_MISS_SIMULATE_RESULT, "missing local simulation result");
        }

        return (CODE_SUCCESS, "");
    }

    /**
     * @dev UA execute the logic by _packets, and return simulation result for precrime. would revert state after returned result.
     * @param _packets packets
     * @return code
     * @return result
     */
    function _simulate(Packet[] calldata _packets) internal view returns (uint16, bytes memory) {
        uint totalSupply = oftView.getCurrentState();

        for (uint i = 0; i < _packets.length; i++) {
            Packet memory packet = _packets[i];
            totalSupply = oftView.lzReceive(packet.srcChainId, packet.srcAddress, packet.payload, totalSupply);
        }

        return (CODE_SUCCESS, abi.encode(SimulationResult({chainTotalSupply: totalSupply, isProxy: oftView.isProxy()})));
    }

    /**
     * @dev
     * @param _simulation all simulation results from difference chains
     * @return code     precrime result code; check out the error code defination
     * @return reason   error reason
     */
    function _precrime(bytes[] memory _simulation) internal pure returns (uint16 code, bytes memory reason) {
        uint totalLocked = 0;
        uint totalMinted = 0;

        for (uint i = 0; i < _simulation.length; i++) {
            SimulationResult memory result = abi.decode(_simulation[i], (SimulationResult));
            if (result.isProxy) {
                if (totalLocked > 0) {
                    return (CODE_PRECRIME_FAILURE, "more than one proxy simulation");
                }
                totalLocked = result.chainTotalSupply;
            } else {
                totalMinted += result.chainTotalSupply;
            }
        }

        if (totalMinted > totalLocked) {
            return (CODE_PRECRIME_FAILURE, "total minted > total locked");
        }

        return (CODE_SUCCESS, "");
    }

    /**
     * @dev Always returns all remote chain ids and precrime addresses
     */
    function _remotePrecrimeAddress(
        Packet[] calldata
    ) internal view returns (uint16[] memory chainIds, bytes32[] memory precrimeAddresses) {
        return (remoteChainIds, remotePrecrimeAddresses);
    }

    /**
     * @dev max batch size for simulate
     */
    function _maxBatchSize() internal view virtual returns (uint64) {
        return maxBatchSize;
    }

    /**
     * get srcChain & srcAddress InboundNonce by packet
     */
    function _getInboundNonce(Packet memory _packet) internal view returns (uint64) {
        return oftView.getInboundNonce(_packet.srcChainId);
    }
}
