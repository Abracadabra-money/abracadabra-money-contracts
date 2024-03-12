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

        
        /*
            Verify staking contract created by the bootstrapper

            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address,uint,uint,uint,address)" "0xC83D75Dd43cc7B11317b89b7163604aFb184EFF8" 30000 604800 7862400 "0xAD773d8D7E3ca2EED69601A1E4A7AFFC062C751A") \
                --compiler-version v0.8.20+commit.a1b79de6 0x9d7224A6ec725008D9B328f0debD6fdb1e54756D src/staking/LockingMultiRewards.sol:LockingMultiRewards \
                --verifier-url https://api.blastscan.io/api \
                -e ${BLAST_ETHERSCAN_KEY}
        */
        bootstrapper = deploy("Onboarding_Bootstrapper", "BlastOnboardingBoot.sol:BlastOnboardingBoot", "");
        vm.stopBroadcast();
    }
}
