// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ICheckpointToken {
    function user_checkpoint(address _account) external returns(bool);
}