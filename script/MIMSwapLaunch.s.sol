// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "script/MIMSwap.s.sol";
import {BlastOnboardingBoot} from "/blast/BlastOnboardingBoot.sol";

contract MIMSwapLaunchScript is BaseScript {
    function deploy()
        public
        returns (address bootstrapper, MagicLP implementation, FeeRateModel feeRateModel, Factory factory, Router router)
    {
        MIMSwapScript script = new MIMSwapScript();

        // Reuse existing deployment unless we're testing
        {
            setNewDeploymentEnabled(false);
            (implementation, feeRateModel, factory, router) = script.deploy();
            setNewDeploymentEnabled(true);
        }

        vm.startBroadcast();
        bootstrapper = deploy("Onboarding_Bootstrapper", "BlastOnboardingBoot.sol:BlastOnboardingBoot", "");
        vm.stopBroadcast();
    }
}
