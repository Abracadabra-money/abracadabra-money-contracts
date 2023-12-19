// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ILiquityStabilityPool {
    function registerFrontEnd(uint256 _kickbackRate) external;

    function provideToSP(uint256 _amount, address _frontEndTag) external;

    function withdrawFromSP(uint256 _amount) external;

    function offset(uint256 _debt, uint256 _coll) external;

    function getETH() external view returns (uint256);

    function getTotalLUSDDeposits() external view returns (uint256);

    function getDepositorETHGain(address _depositor) external view returns (uint256);

    function getDepositorLQTYGain(address _depositor) external view returns (uint256);

    function getCompoundedLUSDDeposit(address _depositor) external view returns (uint256);

    function getCompoundedFrontEndStake(address _frontEnd) external view returns (uint256);
}
