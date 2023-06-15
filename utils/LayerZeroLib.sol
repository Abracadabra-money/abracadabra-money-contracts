// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library LayerZeroLib {
    uint256 internal constant ld2sdRate = 10 ** (18 - 8);
    uint8 internal constant PT_SEND = 0;
    uint8 internal constant PT_SEND_AND_CALL = 1;

    function getRecipient(address remote, address local) internal pure returns (bytes memory) {
        return abi.encodePacked(remote, local);
    }

    function ld2sd(uint _amount) internal pure returns (uint64) {
        uint amountSD = _amount / ld2sdRate;
        require(amountSD <= type(uint64).max, "OFTCore: amountSD overflow");
        return uint64(amountSD);
    }

    function sd2ld(uint64 _amountSD) internal pure returns (uint) {
        return _amountSD * ld2sdRate;
    }
}
