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
        feeTo = toolkit.getAddress("safe.yields");

        if (block.chainid == ChainId.Blast) {
            (implementation, feeRateModel, factory, router) = _deployBlast();
        } else {
            (implementation, feeRateModel, factory, router) = _defaultDefault();
        }

        deploy("MagicLPLens", "MagicLPLens.sol:MagicLPLens", "");
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

/*
Deployment on HyperEVM Testnet
# Shell script for deploying contracts using forge create
#!/bin/bash

# Set your RPC URL and other variables
RPC_URL="https://api.hyperliquid-testnet.xyz/evm"
TX_ORIGIN="0xfB3485c2e209A5cfBDC1447674256578f1A80eE3"
FEE_TO="0xfB3485c2e209A5cfBDC1447674256578f1A80eE3"
OWNER="0xfB3485c2e209A5cfBDC1447674256578f1A80eE3"
WETH="0xB734c264F83E39Ef6EC200F99550779998cC812d"

# Deploy MagicLP implementation
MAGIC_LP=$(forge create --rpc-url $RPC_URL --account deployer src/mimswap/MagicLP.sol:MagicLP --constructor-args $TX_ORIGIN | grep "Deployed to:" | awk '{ print $3 }')
echo "MagicLP deployed to: $MAGIC_LP"

# Deploy FeeRateModel
FEE_RATE_MODEL=$(forge create --rpc-url $RPC_URL --account deployer src/mimswap/auxiliary/FeeRateModel.sol:FeeRateModel --constructor-args $FEE_TO $TX_ORIGIN | grep "Deployed to:" | awk '{ print $3 }')
echo "FeeRateModel deployed to: $FEE_RATE_MODEL"

# Deploy FeeRateModelImpl
FEE_RATE_MODEL_IMPL=$(forge create --rpc-url $RPC_URL --account deployer src/mimswap/auxiliary/FeeRateModelImpl.sol:FeeRateModelImpl | grep "Deployed to:" | awk '{ print $3 }')
echo "FeeRateModelImpl deployed to: $FEE_RATE_MODEL_IMPL"

# Deploy Factory
FACTORY=$(forge create --rpc-url $RPC_URL --account deployer src/mimswap/periphery/Factory.sol:Factory --constructor-args $MAGIC_LP $FEE_RATE_MODEL $OWNER | grep "Deployed to:" | awk '{ print $3 }')
echo "Factory deployed to: $FACTORY"

# Deploy Router
ROUTER=$(forge create --rpc-url $RPC_URL --account deployer src/mimswap/periphery/Router.sol:Router --constructor-args $WETH $FACTORY | grep "Deployed to:" | awk '{ print $3 }')
echo "Router deployed to: $ROUTER"

# Deploy PrivateRouter
PRIVATE_ROUTER=$(forge create --rpc-url $RPC_URL --account deployer src/mimswap/periphery/PrivateRouter.sol:PrivateRouter --constructor-args $WETH $FACTORY $OWNER | grep "Deployed to:" | awk '{ print $3 }')
echo "PrivateRouter deployed to: $PRIVATE_ROUTER"

echo "Deployment complete. Please save these addresses for future reference."
*/