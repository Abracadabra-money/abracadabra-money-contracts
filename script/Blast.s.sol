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

contract BlastScript is BaseScript {
    function deploy() public returns (address blastBox) {
        address owner = toolkit.getAddress(ChainId.Blast, "safe.ops");
        address feeTo = toolkit.getAddress(ChainId.Blast, "safe.ops");

        (address blastGovernor, address blastTokenRegistry) = deployPrerequisites(owner, feeTo);

        vm.startBroadcast();

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address,address)" "0x4300000000000000000000000000000000000004" "0x4C44B16422c4cd58a37aAD4Fc3b8b376393a91dC" "0x0451ADD899D63Ba6A070333550137c3e9691De7d") \
                --compiler-version v0.8.20+commit.a1b79de6 0xC8f5Eb8A632f9600D1c7BC91e97dAD5f8B1e3748 src/blast/BlastBox.sol:BlastBox \
                --verifier-url https://api.blastscan.io/api \
                -e ${BLAST_ETHERSCAN_KEY}
        */
        blastBox = deploy(
            "BlastBox",
            "BlastBox.sol:BlastBox",
            abi.encode(toolkit.getAddress(ChainId.Blast, "weth"), blastTokenRegistry, feeTo)
        );

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address,address)" "0xC8f5Eb8A632f9600D1c7BC91e97dAD5f8B1e3748" "0x76DA31D7C9CbEAE102aff34D3398bC450c8374c1" "0xaE031bDe8582BE194AEeBc097710c97a538BBE90") \
                --compiler-version v0.8.20+commit.a1b79de6 0x802762e604CE08a79DA2BA809281D727A690Fa0d src/blast/BlastCauldronV4.sol:BlastCauldronV4 \
                --verifier-url https://api.blastscan.io/api \
                -e ${BLAST_ETHERSCAN_KEY}
        */
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

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address)" "0x0451ADD899D63Ba6A070333550137c3e9691De7d" "0x0451ADD899D63Ba6A070333550137c3e9691De7d") \
                --compiler-version v0.8.20+commit.a1b79de6 0xaE031bDe8582BE194AEeBc097710c97a538BBE90 src/blast/BlastGovernor.sol:BlastGovernor \
                --verifier-url https://api.blastscan.io/api \
                -e ${BLAST_ETHERSCAN_KEY}
        */
        blastGovernor = deploy("BlastGovernor", "BlastGovernor.sol:BlastGovernor", abi.encode(feeTo, owner));

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address)" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3") \
                --compiler-version v0.8.20+commit.a1b79de6 0x4C44B16422c4cd58a37aAD4Fc3b8b376393a91dC src/blast/BlastTokenRegistry.sol:BlastTokenRegistry \
                --verifier-url https://api.blastscan.io/api \
                -e ${BLAST_ETHERSCAN_KEY}
        */
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
        }
        vm.stopBroadcast();
    }
}
