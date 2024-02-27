// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {BlastOnboarding} from "/blast/BlastOnboarding.sol";
import {BlastScript} from "script/Blast.s.sol";

contract BlastOnboardingScript is BaseScript {
    function deploy() public returns (BlastOnboarding onboarding) {
        BlastScript blastScript = new BlastScript();
        address feeTo = toolkit.getAddress(block.chainid, "safe.ops");

        (, address blastTokenRegistry) = blastScript.deployPrerequisites(tx.origin, feeTo);

        vm.startBroadcast();
        onboarding = BlastOnboarding(
            payable(deploy("BlastOnboarding", "BlastOnboarding.sol:BlastOnboarding", abi.encode(blastTokenRegistry, feeTo, tx.origin)))
        );

        if (!testing()) {
            address usdb = toolkit.getAddress(block.chainid, "usdb");
            address mim = toolkit.getAddress(block.chainid, "mim");
            if (!onboarding.supportedTokens(usdb)) {
                onboarding.setTokenSupported(usdb, true);
            }
            if (!onboarding.supportedTokens(mim)) {
                onboarding.setTokenSupported(mim, true);
            }
        }

        vm.stopBroadcast();
    }
}
