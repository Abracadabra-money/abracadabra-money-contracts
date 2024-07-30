// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Owned} from "@solmate/auth/Owned.sol";
import "utils/BaseScript.sol";
import {MagicLP} from "/mimswap/MagicLP.sol";
import {Factory} from "/mimswap/periphery/Factory.sol";
import {Router} from "/mimswap/periphery/Router.sol";
import {FeeRateModel} from "/mimswap/auxiliary/FeeRateModel.sol";

contract MIMSwapScript is BaseScript {
    bytes32 constant ROUTER_SALT = bytes32(keccak256("MIMSwap_Router_1722288970"));

    address safe;
    address weth;
    address owner;
    address feeTo;

    function deploy() public returns (MagicLP implementation, FeeRateModel feeRateModel, Factory factory, Router router) {
        safe = toolkit.getAddress(block.chainid, "safe.ops");
        weth = toolkit.getAddress(block.chainid, "weth");
        owner = safe;
        feeTo = toolkit.getAddress(block.chainid, "safe.yields");

        if (block.chainid == ChainId.Blast) {
            (implementation, feeRateModel, factory, router) = _deployBlast();
        } else {
            (implementation, feeRateModel, factory, router) = _defaultDefault();
        }
    }

    function _defaultDefault() private returns (MagicLP implementation, FeeRateModel feeRateModel, Factory factory, Router router) {
        vm.startBroadcast();
        implementation = MagicLP(deploy("MIMSwap_MagicLPImplementation", "MagicLP.sol:MagicLP", abi.encode(tx.origin)));

        feeRateModel = FeeRateModel(
            deploy("MIMSwap_MaintainerFeeRateModel", "FeeRateModel.sol:FeeRateModel", abi.encode(feeTo, tx.origin))
        );

        address feeRateModelImpl = deploy("MIMSwap_MaintainerFeeRateModel_Impl", "FeeRateModelImpl.sol:FeeRateModelImpl", "");

        if (feeRateModel.implementation() != feeRateModelImpl) {
            feeRateModel.setImplementation(feeRateModelImpl);
        }

        factory = Factory(deploy("MIMSwap_Factory", "Factory.sol:Factory", abi.encode(implementation, feeRateModel, owner)));

        router = Router(
            payable(
                deployUsingCreate3(
                    "MIMSwap_Router",
                    ROUTER_SALT,
                    "Router.sol:Router",
                    abi.encode(toolkit.getAddress(block.chainid, "weth"), factory)
                )
            )
        );

        address privateRouter = deploy(
            "MIMSwap_PrivateRouter",
            "PrivateRouter.sol:PrivateRouter",
            abi.encode(toolkit.getAddress(block.chainid, "weth"), factory, owner)
        );

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

    function _deployBlast() private returns (MagicLP implementation, FeeRateModel feeRateModel, Factory factory, Router router) {
        address blastGovernor = toolkit.getAddress(block.chainid, "blastGovernor");
        address blastTokenRegistry = toolkit.getAddress(block.chainid, "blastTokenRegistry");

        vm.startBroadcast();

        implementation = MagicLP(
            deploy("MIMSwap_MagicLPImplementation", "BlastMagicLP.sol:BlastMagicLP", abi.encode(blastTokenRegistry, feeTo, tx.origin))
        );

        feeRateModel = FeeRateModel(
            deploy("MIMSwap_MaintainerFeeRateModel", "BlastFeeRateModel.sol:BlastFeeRateModel", abi.encode(feeTo, tx.origin, blastGovernor))
        );

        address feeRateModelImpl = deploy(
            "MIMSwap_MaintainerFeeRateModel_Impl",
            "BlastFeeRateModel.sol:BlastFeeRateModelImpl",
            abi.encode(blastGovernor)
        );

        if (feeRateModel.implementation() != feeRateModelImpl) {
            feeRateModel.setImplementation(feeRateModelImpl);
        }

        factory = Factory(
            deploy(
                "MIMSwap_Factory",
                "BlastMIMSwapFactory.sol:BlastMIMSwapFactory",
                abi.encode(implementation, feeRateModel, owner, blastGovernor)
            )
        );

        router = Router(
            payable(
                deployUsingCreate3(
                    "MIMSwap_Router",
                    ROUTER_SALT,
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
            if (Owned(address(factory)).owner() != owner) {
                Owned(address(factory)).transferOwnership(owner);
            }
        }

        vm.stopBroadcast();
    }
}
