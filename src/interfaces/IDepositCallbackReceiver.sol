pragma solidity ^0.8.0;

import {GmxV2Deposit, GmxV2EventUtils} from "/libraries/GmxV2Libs.sol";

// @title IDepositCallbackReceiver
// @dev interface for a deposit callback contract
interface IDepositCallbackReceiver {
    // @dev called after a deposit execution
    // @param key the key of the deposit
    // @param deposit the deposit that was executed
    function afterDepositExecution(bytes32 key, GmxV2Deposit.Props memory deposit, GmxV2EventUtils.EventLogData memory eventData) external;

    // @dev called after a deposit cancellation
    // @param key the key of the deposit
    // @param deposit the deposit that was cancelled
    function afterDepositCancellation(bytes32 key, GmxV2Deposit.Props memory deposit, GmxV2EventUtils.EventLogData memory eventData) external;
}