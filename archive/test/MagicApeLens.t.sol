// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MagicApeLens.s.sol";
import "periphery/MagicApeLens.sol";

contract MagicAPELensTest is BaseTest {
    MagicAPELens lens;

    struct PoolInfo {
        uint256 apr;
        uint256 stakedAmount;
        uint96 rewardPoolPerHour;
        uint96 rewardPoolPerDay;
        uint256 rewardPerHour;
        uint256 rewardPerDay;
    }

    function setUp() public override {
        fork(ChainId.Mainnet, 16604043);
        super.setUp();

        MagicAPELensScript script = new MagicAPELensScript();
        script.setTesting(true);
        (lens) = script.deploy();
    }

    function testGetContract() public {
        assertEq(lens.APE_COIN_CONTRACT(), 0x4d224452801ACEd8B2F0aebE155379bb5D594381);
    }

    function testGetApeCoinInfo() public {
        MagicAPELens.PoolInfo memory info = lens.getApeCoinInfo();
        assertEq(info.apr, 8995);
        assertEq(info.stakedAmount, 46820047242654258428850215);
        assertEq(info.poolRewardsPerHour, 4807692307692307692307);
        assertEq(info.poolRewardsPerDay, 115384615384615384615368);
        assertEq(info.rewardPerHour, 102684482200017);
        assertEq(info.poolRewardsPerTokenPerDay, 2464427572800408);
    }

    function testGetBAYCInfo() public {
        MagicAPELens.PoolInfo memory info = lens.getBAYCInfo();
        assertEq(info.apr, 15915);
        assertEq(info.stakedAmount, 41548943562039693639021069);
        assertEq(info.poolRewardsPerHour, 7548878205128205128205);
        assertEq(info.poolRewardsPerDay, 181173076923076923076920);
        assertEq(info.rewardPerHour, 181686405428249);
        assertEq(info.poolRewardsPerTokenPerDay, 4360473730277976);
    }

    function testGetMAYCInfo() public {
        MagicAPELens.PoolInfo memory info = lens.getMAYCInfo();
        assertEq(info.apr, 17133);
        assertEq(info.stakedAmount, 15617039688594128216918729);
        assertEq(info.poolRewardsPerHour, 3054487179487179487179);
        assertEq(info.poolRewardsPerDay, 73307692307692307692296);
        assertEq(info.rewardPerHour, 195586823136398);
        assertEq(info.poolRewardsPerTokenPerDay, 4694083755273552);
    }

    function testGetBAKCInfo() public {
        MagicAPELens.PoolInfo memory info = lens.getBAKCInfo();
        assertEq(info.apr, 17114);
        assertEq(info.stakedAmount, 3145739558432464916138858);
        assertEq(info.poolRewardsPerHour, 614583333333333333333);
        assertEq(info.poolRewardsPerDay, 14749999999999999999992);
        assertEq(info.rewardPerHour, 195370062243672);
        assertEq(info.poolRewardsPerTokenPerDay, 4688881493848128);
    }
}
