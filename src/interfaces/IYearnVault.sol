// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";

interface IYearnVault is IERC20 {
    function withdraw() external returns (uint256);

    function deposit(uint256 amount, address recipient) external returns (uint256);

    function pricePerShare() external view returns (uint256);

    function token() external view returns (address);

    function decimals() external view returns (uint256);
}
