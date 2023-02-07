// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/ICauldronV4.sol";
import "interfaces/ICauldronRewarder.sol";

interface ICauldronV4WithRewarder is ICauldronV4 {
    function ACTION_HARVEST_FROM_REWARDER() external view returns (uint8);

    function setRewarder(ICauldronRewarder rewarder) external;
}
