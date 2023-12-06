// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {ICauldronV2} from "interfaces/ICauldronV2.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {IGmxV2DepositCallbackReceiver, IGmxV2Deposit, IGmxV2EventUtils} from "interfaces/IGmxV2.sol";

library GmTestLib {
    function callAfterDepositExecution(IGmxV2DepositCallbackReceiver target) internal {
        bytes32 key = bytes32(0);

        // Prepare the call data
        address[] memory longTokenSwapPath = new address[](0);
        address[] memory shortTokenSwapPath = new address[](0);

        IGmxV2Deposit.Addresses memory addresses = IGmxV2Deposit.Addresses(
            address(target),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            longTokenSwapPath,
            shortTokenSwapPath
        );

        IGmxV2Deposit.Numbers memory numbers = IGmxV2Deposit.Numbers(0, 0, 0, 0, 0, 0);
        IGmxV2Deposit.Flags memory flags = IGmxV2Deposit.Flags(false);
        IGmxV2Deposit.Props memory deposit = IGmxV2Deposit.Props(addresses, numbers, flags);

        bytes memory data = "";
        for (uint i = 0; i < 7; i++) {
            data = abi.encodePacked(data, hex"0000000000000000000000000000000000000000000000000000000000000000");
        }

        IGmxV2EventUtils.EventLogData memory eventData = abi.decode(data, (IGmxV2EventUtils.EventLogData));
        target.afterDepositExecution(key, deposit, eventData);
    }
}
