// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IKodiakVaultStaking} from "/interfaces/IKodiak.sol";

interface IMagicKodiakVault {
    function staking() external view returns (IKodiakVaultStaking);

    function harvest(address harvester) external;

    function distributeRewards(uint256 amount) external;
}
