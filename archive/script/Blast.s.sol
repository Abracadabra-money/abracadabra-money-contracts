// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";
import {IBlastBox} from "/blast/interfaces/IBlastBox.sol";
import {FeeCollectable} from "mixins/FeeCollectable.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {BlastTokenRegistry} from "/blast/BlastTokenRegistry.sol";
import {ICauldronV4} from "interfaces/ICauldronV4.sol";
import {BlastPoints} from "/blast/libraries/BlastPoints.sol";
import {BlastGovernor} from "/blast/BlastGovernor.sol";

contract BlastScript is BaseScript {
    function deploy() public returns (address blastBox) {
        address owner = toolkit.getAddress(ChainId.Blast, "safe.ops");
        address feeTo = toolkit.getAddress(ChainId.Blast, "safe.ops");

        (address blastGovernor, address blastTokenRegistry) = deployPrerequisites(owner, feeTo);

        vm.startBroadcast();

        blastBox = deploy(
            "BlastBox",
            "BlastBox.sol:BlastBox",
            abi.encode(toolkit.getAddress(ChainId.Blast, "weth"), blastTokenRegistry, feeTo)
        );

        ICauldronV4 cauldron = ICauldronV4(
            deploy(
                "CauldronV4_MC",
                "BlastCauldronV4.sol:BlastCauldronV4",
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
            if (Owned(address(cauldron)).owner() != owner) {
                Owned(address(cauldron)).transferOwnership(owner);
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
            if (BoringOwnable(address(blastBox)).owner() != owner) {
                BoringOwnable(address(blastBox)).transferOwnership(owner, true, false);
            }
        }
        vm.stopBroadcast();
    }

    function deployPrerequisites(address owner, address feeTo) public returns (address blastGovernor, address blastTokenRegistry) {
        vm.startBroadcast();
        blastGovernor = deploy("BlastGovernor", "BlastGovernor.sol:BlastGovernor", abi.encode(feeTo, owner));
        blastTokenRegistry = deploy("BlastTokenRegistry", "BlastTokenRegistry.sol:BlastTokenRegistry", abi.encode(tx.origin));

        if (!testing()) {
            address weth = toolkit.getAddress(ChainId.Blast, "weth");
            address usdb = toolkit.getAddress(ChainId.Blast, "usdb");

            if (!BlastTokenRegistry(blastTokenRegistry).nativeYieldTokens(weth)) {
                BlastTokenRegistry(blastTokenRegistry).setNativeYieldTokenEnabled(weth, true);
            }
            if (!BlastTokenRegistry(blastTokenRegistry).nativeYieldTokens(usdb)) {
                BlastTokenRegistry(blastTokenRegistry).setNativeYieldTokenEnabled(usdb, true);
            }
            if (BlastTokenRegistry(blastTokenRegistry).owner() != owner) {
                BlastTokenRegistry(blastTokenRegistry).transferOwnership(owner);
            }
            if (BlastGovernor(payable(blastGovernor)).owner() != owner) {
                BlastGovernor(payable(blastGovernor)).transferOwnership(owner);
            }
        }
        vm.stopBroadcast();
    }
}
