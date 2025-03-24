// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IInfraredStaking} from "/interfaces/IInfraredStaking.sol";

interface IMagicInfraredVault {
    function staking() external view returns (IInfraredStaking);

    function harvest(address harvester) external;

    function distributeRewards(uint256 amount) external;
}
