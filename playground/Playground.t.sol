// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseTest.sol";
import "utils/CauldronDeployLib.sol";
import {MSpellStakingSpoke} from "/governance/MSpellStakingWithVoting.sol";

/// @dev A Script to run any kind of quick test
contract Playground is BaseTest {
    function test() public {
        fork(ChainId.Mainnet, 20672188);

        pushPrank(0xfB3485c2e209A5cfBDC1447674256578f1A80eE3);
        MSpellStakingSpoke staking = MSpellStakingSpoke(0x7D50DB1b90a1B269EA9f795fD2FA763406Cf7FE8);

        uint fee = staking.estimateBridgingFee();

        staking.deposit{value: fee}(22384740475521617805424);
        popPrank();
    }
}
