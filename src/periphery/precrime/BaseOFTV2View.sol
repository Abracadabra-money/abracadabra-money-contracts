// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ILzBaseOFTV2, ILzApp, ILzEndpoint, IOFTV2View} from "interfaces/ILayerZero.sol";
import {BytesLib} from "libraries/BytesLib.sol";
import {IERC20, BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";

abstract contract BaseOFTV2View is IOFTV2View {
    error ErrNotTrustedRemote();
    error ErrInvalidPathLength();

    using BytesLib for bytes;
    using BoringERC20 for IERC20;

    ILzApp public immutable oft;
    IERC20 public immutable token;
    ILzEndpoint public immutable endpoint;

    /// @notice Local decimals to shared decimals rate
    uint public immutable ld2sdRate;

    constructor(address _oft) {
        oft = ILzApp(_oft);
        token = IERC20(address(ILzBaseOFTV2(_oft).innerToken()));
        endpoint = ILzApp(_oft).lzEndpoint();

        uint8 decimals = token.safeDecimals();
        uint8 sharedDecimals = ILzBaseOFTV2(_oft).sharedDecimals();
        ld2sdRate = 10 ** (decimals - sharedDecimals);
    }

    function _decodePayload(bytes memory _payload) internal view returns (uint) {
        uint64 amountSD = _payload.toUint64(33);
        return amountSD * ld2sdRate;
    }

    function getInboundNonce(uint16 _srcChainId) external view virtual returns (uint64) {
        bytes memory path = oft.trustedRemoteLookup(_srcChainId);
        return endpoint.getInboundNonce(_srcChainId, path);
    }

    function _isPacketFromTrustedRemote(uint16 _srcChainId, bytes32 _srcAddress) internal view returns (bool) {
        bytes memory path = oft.trustedRemoteLookup(_srcChainId);
        uint pathLength = path.length;

        // EVM - EVM path length 40 (address + address)
        // EVM - non-EVM path length 52 (bytes32 + address)
        if (pathLength != 40 && pathLength != 52) {
            revert ErrInvalidPathLength();
        }

        // path format: remote + local
        path = path.slice(0, pathLength - 20);

        uint remoteAddressLength = path.length;
        uint mask = (2 ** (remoteAddressLength * 8)) - 1;
        bytes32 remoteUaAddress;

        assembly {
            remoteUaAddress := and(mload(add(path, remoteAddressLength)), mask)
        }

        return remoteUaAddress == _srcAddress;
    }

    function lzReceive(
        uint16 _srcChainId,
        bytes32 _scrAddress,
        bytes memory _payload,
        uint _totalSupply
    ) external view virtual returns (uint);

    function getCurrentState() external view virtual returns (uint);

    function isProxy() external view virtual returns (bool);
}
