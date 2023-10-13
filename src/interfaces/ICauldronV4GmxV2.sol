// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/ICauldronV4.sol";

interface ICauldronV4GmxV2 is ICauldronV4 {
    function closeOrder(address user) external;
}
