// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/ICauldronV3.sol";

interface ICauldronV4 is ICauldronV3 {
    function setBlacklistedCallee(address callee, bool blacklisted) external;

    function repayForAll(uint128 amount, bool skim) external returns (uint128);

    function setAllowedSupplyReducer(address account, bool allowed) external;
}
