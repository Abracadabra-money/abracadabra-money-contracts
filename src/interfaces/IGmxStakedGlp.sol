// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IGmxStakedGlp {
    function allowance(address _owner, address _spender) external view returns (uint256);

    function allowances(address, address) external view returns (uint256);

    function approve(address _spender, uint256 _amount) external returns (bool);

    function balanceOf(address _account) external view returns (uint256);

    function decimals() external view returns (uint8);

    function feeGlpTracker() external view returns (address);

    function glp() external view returns (address);

    function glpManager() external view returns (address);

    function name() external view returns (string memory);

    function stakedGlpTracker() external view returns (address);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(address _recipient, uint256 _amount) external returns (bool);

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external returns (bool);
}
