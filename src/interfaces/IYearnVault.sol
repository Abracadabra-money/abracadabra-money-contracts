// SPDX-License-Identifier: MIT
// solhint-disable func-name-mixedcase, var-name-mixedcase
pragma solidity >=0.8.0;
import "BoringSolidity/interfaces/IERC20.sol";

interface IYearnVault is IERC20 {
    function withdraw() external returns (uint256);
    function deposit(uint256 amount, address recipient) external returns (uint256);
    function pricePerShare() external view returns (uint256);
    function token() external view returns (address);
    function decimals() external view returns (uint256);
}