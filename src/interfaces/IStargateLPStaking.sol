// SPDX-License-Identifier: BUSL-1.1
// solhint-disable func-name-mixedcase
pragma solidity >=0.8.0;

interface IStargateLPStaking {
    function deposit(uint256 _pid, uint256 _amount) external;

    function emergencyWithdraw(uint256 _pid) external;

    function poolInfo(uint256)
        external
        view
        returns (
            address lpToken,
            uint256 allocPoint,
            uint256 lastReward,
            uint256 accEmissionPerShare
        );

    function userInfo(uint256, address) external view returns (uint256 amount, uint256 rewardDebt);

    function withdraw(uint256 _pid, uint256 _amount) external;
}
