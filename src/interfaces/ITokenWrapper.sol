// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";

interface ITokenWrapper is IERC20 {
    function underlying() external view returns (IERC20);

    function unwrap(uint256 amount) external;

    function unwrapAll() external;

    function unwrapAllTo(address recipient) external;

    function unwrapTo(uint256 amount, address recipient) external;

    function wrap(uint256 amount) external;

    function wrapFor(uint256 amount, address recipient) external;
}
