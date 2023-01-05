// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";

interface IRewarder {
    function updateReward(IERC20 token) external;
    function deposit(address from, uint256 _amount) external;
    function withdraw(address from, uint256 _amount) external;
    function harvest(address to) external returns (uint256);
    function pendingReward(address _user) external view returns (uint256);
    function harvestMultiple(address[] calldata to) external;
}
