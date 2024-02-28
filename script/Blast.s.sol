// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {IBlastBox} from "/blast/interfaces/IBlastBox.sol";
import {FeeCollectable} from "mixins/FeeCollectable.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {BlastTokenRegistry} from "/blast/BlastTokenRegistry.sol";
import {ICauldronV4} from "interfaces/ICauldronV4.sol";
import {BlastPoints} from "/blast/libraries/BlastPoints.sol";

contract BlastScript is BaseScript {
    function deploy() public returns (address blastBox) {
        address feeTo = toolkit.getAddress(ChainId.Blast, "safe.ops");

        (address blastGovernor, address blastTokenRegistry) = deployPrerequisites(tx.origin, feeTo);

        vm.startBroadcast();

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --compiler-version v0.8.20+commit.a1b79de6 0xDEA1B44b710Af105f4a0c0Ab734a7b8f543e9D70 src/blast/BlastDapp.sol:BlastDapp \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        deploy("Dapp", "BlastDapp.sol:BlastDapp", "");

        blastBox = deploy(
            "BlastBox",
            "BlastBox.sol:BlastBox",
            abi.encode(toolkit.getAddress(ChainId.Blast, "weth"), blastTokenRegistry, feeTo)
        );

        ICauldronV4 cauldron = ICauldronV4(
            deploy(
                "CauldronV4_MC",
                "BlastWrappers.sol:BlastCauldronV4",
                abi.encode(blastBox, toolkit.getAddress(block.chainid, "mim"), blastGovernor)
            )
        );

        if (!testing()) {
            address weth = toolkit.getAddress(ChainId.Blast, "weth");
            address usdb = toolkit.getAddress(ChainId.Blast, "usdb");
            address mim = toolkit.getAddress(ChainId.Blast, "mim");

            if (cauldron.feeTo() != feeTo) {
                cauldron.setFeeTo(feeTo);
            }
            if (!IBlastBox(blastBox).enabledTokens(weth)) {
                IBlastBox(blastBox).setTokenEnabled(weth, true);
            }
            if (!IBlastBox(blastBox).enabledTokens(usdb)) {
                IBlastBox(blastBox).setTokenEnabled(usdb, true);
            }
            if (!IBlastBox(blastBox).enabledTokens(mim)) {
                IBlastBox(blastBox).setTokenEnabled(mim, true);
            }
            if (IBlastBox(blastBox).feeTo() != feeTo) {
                IBlastBox(blastBox).setFeeTo(feeTo);
            }
        }
        vm.stopBroadcast();
    }

    function deployPrerequisites(address owner, address feeTo) public returns (address blastGovernor, address blastTokenRegistry) {
        vm.startBroadcast();
        blastGovernor = deploy("BlastGovernor", "BlastGovernor.sol:BlastGovernor", abi.encode(feeTo, tx.origin));
        blastTokenRegistry = deploy("BlastTokenRegistry", "BlastTokenRegistry.sol:BlastTokenRegistry", abi.encode(tx.origin));

        if (!testing()) {
            address weth = toolkit.getAddress(ChainId.Blast, "weth");
            address usdb = toolkit.getAddress(ChainId.Blast, "usdb");

            if (!BlastTokenRegistry(blastTokenRegistry).nativeYieldTokens(weth)) {
                BlastTokenRegistry(blastTokenRegistry).registerNativeYieldToken(weth);
            }
            if (!BlastTokenRegistry(blastTokenRegistry).nativeYieldTokens(usdb)) {
                BlastTokenRegistry(blastTokenRegistry).registerNativeYieldToken(usdb);
            }
            if (BlastTokenRegistry(blastTokenRegistry).owner() != owner) {
                BlastTokenRegistry(blastTokenRegistry).transferOwnership(owner);
            }
        }
        vm.stopBroadcast();
    }
}
