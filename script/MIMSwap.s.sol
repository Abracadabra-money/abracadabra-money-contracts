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
        } else {
            revert("unsupported chain");
        }
    }

    function _deployBlast() private returns (MagicLP implementation, FeeRateModel feeRateModel, Factory factory, Router router) {
        BlastScript blastScript = new BlastScript();
        (address blastGovernor, address blastTokenRegistry) = blastScript.deployPrerequisites(tx.origin, feeTo);

        vm.startBroadcast();

        implementation = MagicLP(
            deploy("MIMSwap_MagicLPImplementation", "BlastMagicLP.sol:BlastMagicLP", abi.encode(blastTokenRegistry, feeTo, tx.origin))
        );
        feeRateModel = FeeRateModel(
            deploy("MIMSwap_MaintainerFeeRateModel", "FeeRateModel.sol:FeeRateModel", abi.encode(maintainer, tx.origin))
        );

        /*address feeRateModelImpl = */ deploy("MIMSwap_MaintainerFeeRateModel_Impl", "FeeRateModelImpl.sol:FeeRateModelImpl", "");
        //if (feeRateModel.implementation() != feeRateModelImpl) {
        //    feeRateModel.setImplementation(feeRateModelImpl);
        //}

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
}
