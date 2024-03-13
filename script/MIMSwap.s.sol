// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {MagicLP} from "/mimswap/MagicLP.sol";
import {Factory} from "/mimswap/periphery/Factory.sol";
import {Router} from "/mimswap/periphery/Router.sol";
import {FeeRateModel} from "/mimswap/auxiliary/FeeRateModel.sol";
import {BlastTokenRegistry} from "/blast/BlastTokenRegistry.sol";
import {BlastScript} from "script/Blast.s.sol";

contract MIMSwapScript is BaseScript {
    address safe;
    address weth;
    address maintainer = safe;
    address owner = safe;
    address feeTo = safe;

    address constant BLAST_ONBOARDING_ADDRESS = 0xa64B73699Cc7334810E382A4C09CAEc53636Ab96;

    function deploy() public returns (MagicLP implementation, FeeRateModel feeRateModel, Factory factory, Router router) {
        safe = toolkit.getAddress(block.chainid, "safe.ops");
        weth = toolkit.getAddress(block.chainid, "weth");
        maintainer = safe;
        owner = safe;
        feeTo = safe;

        if (block.chainid == ChainId.Blast) {
            (implementation, feeRateModel, factory, router) = _deployBlast();
        } else {
            revert("unsupported chain");
        }
    }

    function _deployBlast() private returns (MagicLP implementation, FeeRateModel feeRateModel, Factory factory, Router router) {
        BlastScript blastScript = new BlastScript();
        (address blastGovernor, address blastTokenRegistry) = blastScript.deployPrerequisites(tx.origin, feeTo);

        vm.startBroadcast();

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address,address)" "0x4C44B16422c4cd58a37aAD4Fc3b8b376393a91dC" "0xa7f0d0F56437b61F7Bb6A893e424f3E114e0988F" "0xa7f0d0F56437b61F7Bb6A893e424f3E114e0988F") \
                --compiler-version v0.8.20+commit.a1b79de6 0x480319e8674eb1b2A1A878E60E15A5b711A81FbD src/blast/BlastMagicLP.sol:BlastMagicLP \
                --verifier-url https://api.blastscan.io/api \
                -e ${BLAST_ETHERSCAN_KEY}
        */
        implementation = MagicLP(
            deploy("MIMSwap_MagicLPImplementation", "BlastMagicLP.sol:BlastMagicLP", abi.encode(blastTokenRegistry, feeTo, tx.origin))
        );

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address,address)" "0xa7f0d0F56437b61F7Bb6A893e424f3E114e0988F" "0xa7f0d0F56437b61F7Bb6A893e424f3E114e0988F" "0xaE031bDe8582BE194AEeBc097710c97a538BBE90") \
                --compiler-version v0.8.20+commit.a1b79de6 0xaCC1B5e4962A2cD3b6d7D9FD2bd85FE86c602855 src/blast/BlastFeeRateModel.sol:BlastFeeRateModel \
                --verifier-url https://api.blastscan.io/api \
                -e ${BLAST_ETHERSCAN_KEY}
        */
        feeRateModel = FeeRateModel(
            deploy(
                "MIMSwap_MaintainerFeeRateModel",
                "BlastFeeRateModel.sol:BlastFeeRateModel",
                abi.encode(maintainer, tx.origin, blastGovernor)
            )
        );

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address)" "0xaE031bDe8582BE194AEeBc097710c97a538BBE90") \
                --compiler-version v0.8.20+commit.a1b79de6 0xe29d783abc2ceeC9b4cFc9d3F9c3b3548c1c866b src/blast/BlastFeeRateModel.sol:BlastFeeRateModelImpl \
                --verifier-url https://api.blastscan.io/api \
                -e ${BLAST_ETHERSCAN_KEY}
        */
        address feeRateModelImpl = deploy(
            "MIMSwap_MaintainerFeeRateModel_Impl",
            "BlastFeeRateModel.sol:BlastFeeRateModelImpl",
            abi.encode(blastGovernor)
        );

        if (feeRateModel.implementation() != feeRateModelImpl) {
            feeRateModel.setImplementation(feeRateModelImpl);
        }

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address,address,address)" "0x480319e8674eb1b2A1A878E60E15A5b711A81FbD" "0xaCC1B5e4962A2cD3b6d7D9FD2bd85FE86c602855" "0xa7f0d0F56437b61F7Bb6A893e424f3E114e0988F" "0xaE031bDe8582BE194AEeBc097710c97a538BBE90") \
                --compiler-version v0.8.20+commit.a1b79de6 0x323957ED2BC819B9dF55e64cD7C0Ff3B186A8ADa src/blast/BlastMIMSwapFactory.sol:BlastMIMSwapFactory \
                --verifier-url https://api.blastscan.io/api \
                -e ${BLAST_ETHERSCAN_KEY}
        */
        factory = Factory(
            deploy(
                "MIMSwap_Factory",
                "BlastMIMSwapFactory.sol:BlastMIMSwapFactory",
                abi.encode(implementation, feeRateModel, owner, blastGovernor)
            )
        );

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address,address)" "0x4300000000000000000000000000000000000004" "0x323957ED2BC819B9dF55e64cD7C0Ff3B186A8ADa" "0xaE031bDe8582BE194AEeBc097710c97a538BBE90") \
                --compiler-version v0.8.20+commit.a1b79de6 0x73A5487F13FAB384Db55bB9A054f2d35Ef21737e src/blast/BlastMIMSwapRouter.sol:BlastMIMSwapRouter \
                --verifier-url https://api.blastscan.io/api \
                -e ${BLAST_ETHERSCAN_KEY}
        */
        router = Router(
            payable(
                deploy(
                    "MIMSwap_Router",
                    "BlastMIMSwapRouter.sol:BlastMIMSwapRouter",
                    abi.encode(toolkit.getAddress(block.chainid, "weth"), factory, blastGovernor)
                )
            )
        );

        address privateRouter = deploy(
            "MIMSwap_PrivateRouter",
            "PrivateRouter.sol:PrivateRouter",
            abi.encode(toolkit.getAddress(block.chainid, "weth"), factory, owner)
        );

        if (!implementation.operators(BLAST_ONBOARDING_ADDRESS)) {
            implementation.setOperator(BLAST_ONBOARDING_ADDRESS, true);
        }
        if (!implementation.operators(privateRouter)) {
            implementation.setOperator(privateRouter, true);
        }

        if (!testing()) {
            if (Owned(address(implementation)).owner() != owner) {
                Owned(address(implementation)).transferOwnership(owner);
            }
            if (Owned(address(feeRateModel)).owner() != owner) {
                Owned(address(feeRateModel)).transferOwnership(owner);
            }
            if (Owned(address(factory)).owner() != owner) {
                Owned(address(factory)).transferOwnership(owner);
            }
        }

        vm.stopBroadcast();
    }
}
