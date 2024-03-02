// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MIMSwapLaunch.s.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {BlastOnboarding} from "/blast/BlastOnboarding.sol";
import {BlastOnboardingBoot} from "/blast/BlastOnboardingBoot.sol";

contract MIMSwapLaunchTest is BaseTest {
    using SafeTransferLib for address;

    BlastOnboarding constant onboarding = BlastOnboarding(payable(0xa64B73699Cc7334810E382A4C09CAEc53636Ab96));

    MagicLP implementation;
    FeeRateModel feeRateModel;
    Factory factory;
    Router router;
    address owner;
    BlastOnboardingBoot onboardingBootstrapper;

    address mim;
    address usdb;

    function setUp() public override {
        fork(ChainId.Blast, 272010);
        super.setUp();

        MIMSwapLaunchScript script = new MIMSwapLaunchScript();
        script.setTesting(true);

        address bootstrapper;
        (bootstrapper, implementation, feeRateModel, factory, router) = script.deploy();

        owner = onboarding.owner();

        pushPrank(onboarding.owner());
        onboarding.setBootstrapper(bootstrapper);
        onboardingBootstrapper = BlastOnboardingBoot(address(onboarding));
        onboardingBootstrapper.initialize(router);
        popPrank();

        mim = toolkit.getAddress(block.chainid, "mim");
        usdb = toolkit.getAddress(block.chainid, "usdb");
    }

    function testBoot() public {
        vm.expectRevert("UNAUTHORIZED");
        onboardingBootstrapper.bootstrap(0);

        pushPrank(owner);
        // not closed
        vm.expectRevert(abi.encodeWithSignature("ErrWrongState()"));
        onboardingBootstrapper.bootstrap(0);

        // close event
        onboarding.close();

        // bootstrap
        uint mimBalanceBefore = mim.balanceOf(address(onboarding));
        uint usdbBalanceBefore = usdb.balanceOf(address(onboarding));
        //console2.log("mimBalanceBefore", mimBalanceBefore, mimBalanceBefore/1e18);
        //console2.log("usdbBalanceBefore", usdbBalanceBefore, usdbBalanceBefore/1e18);

        onboardingBootstrapper.bootstrap(0);
        
        uint mimBalanceAfter = mim.balanceOf(address(onboarding));
        uint usdbBalanceAfter = usdb.balanceOf(address(onboarding));
        uint mimBalanceLp = mim.balanceOf(onboardingBootstrapper.pool());
        uint usdbBalanceLp = usdb.balanceOf(onboardingBootstrapper.pool());

        //console2.log("mimBalanceAfter", mimBalanceAfter, mimBalanceAfter/1e18);
        //console2.log("usdbBalanceAfter", usdbBalanceAfter, usdbBalanceAfter/1e18);
        //console2.log("---------------------------------");
        //console2.log("mimBalanceLp", mimBalanceLp, mimBalanceLp/1e18);
        //console2.log("usdbBalanceLp", usdbBalanceLp, usdbBalanceLp/1e18);

        popPrank();
    }
}
