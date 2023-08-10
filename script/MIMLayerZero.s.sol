// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "interfaces/IMintableBurnable.sol";
import "mixins/Operatable.sol";
import "solmate/auth/Owned.sol";
import {ILzFeeHandler} from "interfaces/ILzFeeHandler.sol";

contract MIMLayerZeroScript is BaseScript {
    using DeployerFunctions for Deployer;

    mapping(uint256 => uint256) fixedFees;

    function deploy() public returns (LzProxyOFTV2 proxyOFTV2, LzIndirectOFTV2 indirectOFTV2, address mim) {
        fixedFees[1] = 550000000000000;
        fixedFees[56] = 4188568516917942;
        fixedFees[137] = 1378169790518191841;
        fixedFees[250] = 4145116379323744988;
        fixedFees[10] = 550000000000000;
        fixedFees[42161] = 539272521368673;
        fixedFees[43114] = 75282653144085340;
        fixedFees[1285] = 207750420279100224;
        fixedFees[2222] = 1174694726208026689;
        fixedFees[8453] = 550000000000000;
        fixedFees[59144] = 550000000000000;

        uint8 sharedDecimals = 8;
        address safe = toolkit.getAddress("safe.ops", block.chainid);
        address lzEndpoint = toolkit.getAddress("LZendpoint", block.chainid);
        string memory chainName = toolkit.getChainName(block.chainid);

        if (block.chainid == ChainId.Mainnet) {
            mim = toolkit.getAddress("mim", block.chainid);
            proxyOFTV2 = deployer.deploy_LzProxyOFTV2("Mainnet_ProxyOFTV2", mim, sharedDecimals, lzEndpoint);
            if (!proxyOFTV2.useCustomAdapterParams()) {
                vm.broadcast();
                proxyOFTV2.setUseCustomAdapterParams(true);
            }
        } else {
            if (isChainUsingAnyswap()) {
                mim = toolkit.getAddress("mim", block.chainid);
            } else {
                mim = address(deployer.deploy_MintableBurnableERC20(string.concat(chainName, "_MIM"), tx.origin, "Magic Internet Money", "MIM", 18));
            }

            require(mim != address(0), "MIMLayerZeroScript: mim is not defined");

            indirectOFTV2 = deployer.deploy_LzIndirectOFTV2(
                string.concat(chainName, "_IndirectOFTV2"),
                mim,
                sharedDecimals,
                lzEndpoint
            );

            LzOFTV2FeeHandler feeHandler = deployer.deploy_LzOFTV2FeeHandler(
                string.concat(chainName, "_FeeHandler"),
                tx.origin,
                fixedFees[block.chainid],
                address(indirectOFTV2),
                address(0),
                safe,
                uint8(ILzFeeHandler.QuoteType.Fixed)
            );

            if (indirectOFTV2.feeHandler() != feeHandler) {
                vm.broadcast();
                indirectOFTV2.setFeeHandler(feeHandler);
            }

            if (feeHandler.owner() != safe) {
                vm.broadcast();
                feeHandler.transferOwnership(safe);
            }

            if (!indirectOFTV2.useCustomAdapterParams()) {
                vm.broadcast();
                indirectOFTV2.setUseCustomAdapterParams(true);
            }

            if (!isChainUsingAnyswap()) {
                /// @notice The layerzero token needs to be able to mint/burn anyswap tokens
                /// Only change the operator if the ownership is still the deployer
                if (!Operatable(mim).operators(address(indirectOFTV2)) && BoringOwnable(mim).owner() == tx.origin) {
                    vm.broadcast();
                    Operatable(mim).setOperator(address(indirectOFTV2), true);
                }
            } else {
                // Using Anyswap, need to schedule a call to set indirectOFTV2 as a minter
            }

            if (!testing()) {
                if (Owned(mim).owner() != safe) {
                    vm.broadcast();
                    Owned(mim).transferOwnership(safe);
                }
            }
        }
    }

    function isChainUsingAnyswap() public view returns (bool) {
        return
            block.chainid == ChainId.BSC ||
            block.chainid == ChainId.Polygon ||
            block.chainid == ChainId.Fantom ||
            block.chainid == ChainId.Optimism ||
            block.chainid == ChainId.Arbitrum ||
            block.chainid == ChainId.Avalanche ||
            block.chainid == ChainId.Moonriver;
    }
}
