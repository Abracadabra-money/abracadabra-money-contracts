// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";

interface IRewarder {
    function updateReward(IERC20 token) external;
    function deposit(uint256 _amount, address from) external;
    function withdraw(address from, uint256 _amount) external;
}
