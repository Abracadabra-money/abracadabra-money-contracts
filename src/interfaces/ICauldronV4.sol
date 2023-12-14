// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ICauldronV3} from "interfaces/ICauldronV3.sol";

interface ICauldronV4 is ICauldronV3 {
    function setBlacklistedCallee(address callee, bool blacklisted) external;

    function blacklistedCallees(address callee) external view returns (bool);

    function isSolvent(address user) external view returns (bool);
}
