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

    function deploy() public returns (MagicLP implementation, FeeRateModel feeRateModel, Factory factory, Router router) {
        safe = toolkit.getAddress(block.chainid, "safe.ops");
        weth = toolkit.getAddress(block.chainid, "weth");
        maintainer = safe;
        owner = safe;
        feeTo = safe;

        if (block.chainid == ChainId.Blast) {
            (implementation, feeRateModel, factory, router) = _deployBlast();
        } else if (block.chainid == ChainId.Mainnet) {
            (implementation, feeRateModel, factory, router) = _deployMainnet();
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
                --constructor-args $(cast abi-encode "constructor(address,address,address)" "0x43838338F30795185Dabf1e52DaE6a3FEEdC953d" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3") \
                --compiler-version v0.8.20+commit.a1b79de6 0x8176C5408c5DeC30149232A74Ef8873379b59982 src/blast/BlastMagicLP.sol:BlastMagicLP \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        implementation = MagicLP(
            deploy("MIMSwap_MagicLPImplementation", "BlastMagicLP.sol:BlastMagicLP", abi.encode(blastTokenRegistry, feeTo, tx.origin))
        );

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --compiler-version v0.8.20+commit.a1b79de6 0x00F1E7b5Dcf9247c645D83664faD9ECcd4a84604 src/mimswap/auxiliary/FeeRateModelImpl.sol:FeeRateModelImpl \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        address feeRateModelImpl = deploy("MIMSwap_MaintainerFeeRateModel_Impl", "FeeRateModelImpl.sol:FeeRateModelImpl", "");

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address)" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3") \
                --compiler-version v0.8.20+commit.a1b79de6 0x00F1E7b5Dcf9247c645D83664faD9ECcd4a84604 src/mimswap/auxiliary/FeeRateModel.sol:FeeRateModel \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        feeRateModel = FeeRateModel(
            deploy("MIMSwap_MaintainerFeeRateModel", "FeeRateModel.sol:FeeRateModel", abi.encode(maintainer, tx.origin))
        );

        if (feeRateModel.implementation() != feeRateModelImpl) {
            feeRateModel.setImplementation(feeRateModelImpl);
        }

        /*
            forge verify-contract --num-of-optimizations 400 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address,address,address)" "0xE5683f4bD410ea185692b5e6c9513Be6bf1017ec" "0x00F1E7b5Dcf9247c645D83664faD9ECcd4a84604" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3" "0x25c27fb282c5D974e9B091d45F28BA5dE128e022") \
                --compiler-version v0.8.20+commit.a1b79de6 0xE14Bb36D742404A1099F8908241C90EB914625CB src/blast/BlastWrappers.sol:BlastMIMSwapFactory \
                --verifier-url https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan \
                -e verifyContract
        */
        factory = Factory(
            deploy(
                "MIMSwap_Factory",
                "BlastWrappers.sol:BlastMIMSwapFactory",
                abi.encode(implementation, feeRateModel, owner, blastGovernor)
            )
        );

        // Router
        router = Router(
            payable(
                deploy(
                    "MIMSwap_Router",
                    "BlastWrappers.sol:BlastMIMSwapRouter",
                    abi.encode(toolkit.getAddress(block.chainid, "weth"), factory, blastGovernor)
                )
            )
        );

        if (!testing()) {
            if (Owned(address(implementation)).owner() != owner) {
                Owned(address(implementation)).transferOwnership(owner);
            }
            if (Owned(address(feeRateModel)).owner() != owner) {
                Owned(address(feeRateModel)).transferOwnership(owner);
            }
        }

        vm.stopBroadcast();
    }

    function _deployMainnet() private returns (MagicLP implementation, FeeRateModel feeRateModel, Factory factory, Router router) {
        vm.startBroadcast();

        implementation = MagicLP(deploy("MIMSwap_MagicLPImplementation", "MagicLP.sol:MagicLP", abi.encode(tx.origin)));
        address feeRateModelImpl = deploy("MIMSwap_MaintainerFeeRateModel_Impl", "FeeRateModelImpl.sol:FeeRateModelImpl", "");
        feeRateModel = FeeRateModel(
            deploy("MIMSwap_MaintainerFeeRateModel", "FeeRateModel.sol:FeeRateModel", abi.encode(maintainer, tx.origin))
        );

        if (feeRateModel.implementation() != feeRateModelImpl) {
            feeRateModel.setImplementation(feeRateModelImpl);
        }

        factory = Factory(deploy("MIMSwap_Factory", "Factory.sol:Factory", abi.encode(implementation, feeRateModel, owner)));

        router = Router(
            payable(deploy("MIMSwap_Router", "Router.sol:Router", abi.encode(toolkit.getAddress(block.chainid, "weth"), factory)))
        );

        if (!testing()) {
            if (Owned(address(implementation)).owner() != owner) {
                Owned(address(implementation)).transferOwnership(owner);
            }
            if (Owned(address(feeRateModel)).owner() != owner) {
                Owned(address(feeRateModel)).transferOwnership(owner);
            }
        }

        vm.stopBroadcast();
    }
}
