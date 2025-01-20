// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ILzReceiver} from "@abracadabra-oft-v1/interfaces/ILayerZero.sol";
import {Vm, VmSafe} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {Toolkit} from "utils/Toolkit.sol";
import {LayerZeroLib} from "utils/LayerZeroLib.sol";
import {TestingLib, PrankState} from "./TestingLib.sol";

library LayerZeroTestLib {
    Vm constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
    Toolkit constant toolkit = Toolkit(address(bytes20(uint160(uint256(keccak256("toolkit"))))));

    /// @notice use when receiver is the same address as the sender (when deployed using CREATE2/CREATE3)
    function simulateLzReceive(uint256 fromChainId, uint256 toChainId, address receiver, bytes memory payload) internal returns (uint256) {
        return simulateLzReceive(fromChainId, toChainId, receiver, receiver, payload);
    }

    function simulateLzReceive(
        uint256 fromChainId,
        uint256 toChainId,
        address from,
        address to,
        bytes memory payload
    ) internal returns (uint256 gasUsed) {
        require(
            block.chainid == toChainId,
            string.concat("Current chain ID is ", vm.toString(block.chainid), " but expected ", vm.toString(toChainId))
        );

        uint16 fromLzChainId = toolkit.getLzChainId(fromChainId);
        uint16 toLzChainId = toolkit.getLzChainId(toChainId);
        address endpoint = toolkit.getAddress("LZendpoint");

        console2.log("=== Simulating lzReceive ===");
        console2.log(">> Source");
        console2.log("- Chain ID:", fromChainId);
        console2.log("- Lz Chain ID:", fromLzChainId);
        console2.log("- Address:", from);
        console2.log(">> Destination");
        console2.log("- Chain ID:", toChainId);
        console2.log("- Lz Chain ID:", toLzChainId);
        console2.log("- Address:", to);
        console2.log("== Payload ==");
        console2.logBytes(payload);

        PrankState memory state = TestingLib.safeStartPrank(endpoint);
        uint256 gasLeft = gasleft();
        ILzReceiver(to).lzReceive(fromLzChainId, LayerZeroLib.getRecipient(from, to), 0, payload);
        gasUsed = gasLeft - gasleft();
        TestingLib.safeEndPrank(state);
    }
}
