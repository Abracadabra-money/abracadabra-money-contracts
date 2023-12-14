// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ICauldronV4} from "interfaces/ICauldronV4.sol";
import {IGmCauldronOrderAgent, IGmRouterOrder} from "periphery/GmxV2CauldronOrderAgent.sol";

interface ICauldronV4GmxV2 is ICauldronV4 {
    function closeOrder(address user) external;

    function orders(address user) external view returns (IGmRouterOrder);

    function orderAgent() external view returns (IGmCauldronOrderAgent);
}
