// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {BoringOwnable} from "@BoringSolidity/BoringOwnable.sol";
import {Owned} from "@solmate/auth/Owned.sol";
import "utils/BaseScript.sol";
import {IMintableBurnable} from "/interfaces/IMintableBurnable.sol";
import {IOwnableOperators} from "/interfaces/IOwnableOperators.sol";
import {ILzFeeHandler} from "/interfaces/ILayerZero.sol";
import {LzProxyOFTV2} from "/tokens/LzProxyOFTV2.sol";
import {LzIndirectOFTV2} from "/tokens/LzIndirectOFTV2.sol";
import {LzOFTV2FeeHandler} from "/periphery/LzOFTV2FeeHandler.sol";

contract MIMLayerZeroScript is BaseScript {
    mapping(uint256 => uint256) fixedFees;

    function deploy() public returns (LzProxyOFTV2 proxyOFTV2, LzIndirectOFTV2 indirectOFTV2, IMintableBurnable minterBurner) {
        vm.startBroadcast();

        fixedFees[ChainId.Mainnet] = 550000000000000;
        fixedFees[ChainId.BSC] = 4188568516917942;
        fixedFees[ChainId.Polygon] = 1378169790518191841;
        fixedFees[ChainId.Fantom] = 4145116379323744988;
        fixedFees[ChainId.Optimism] = 550000000000000;
        fixedFees[ChainId.Arbitrum] = 539272521368673;
        fixedFees[ChainId.Avalanche] = 75282653144085340;
        fixedFees[ChainId.Moonriver] = 207750420279100224;
        fixedFees[ChainId.Kava] = 1174694726208026689;
        fixedFees[ChainId.Base] = 550000000000000;
        fixedFees[ChainId.Linea] = 550000000000000;
        fixedFees[ChainId.Blast] = 550000000000000;

        uint8 sharedDecimals = 8;
        address mim;
        address safe = toolkit.getAddress("safe.ops");
        address lzEndpoint = toolkit.getAddress("LZendpoint");

        if (block.chainid == ChainId.Mainnet) {
            mim = toolkit.getAddress("mim");
            proxyOFTV2 = LzProxyOFTV2(
                deploy("MIM_ProxyOFTV2", "LzProxyOFTV2.sol:LzProxyOFTV2", abi.encode(mim, sharedDecimals, lzEndpoint, tx.origin))
            );
            if (!proxyOFTV2.useCustomAdapterParams()) {
                proxyOFTV2.setUseCustomAdapterParams(true);
            }
        } else {
            // uses the same address for MIM and the minterBurner
            mim = address(
                deploy("MIM", "MintableBurnableERC20.sol:MintableBurnableERC20", abi.encode(tx.origin, "Magic Internet Money", "MIM", 18))
            );
            minterBurner = IMintableBurnable(mim);

            require(address(minterBurner) != address(0), "MIMLayerZeroScript: minterBurner is not defined");
            require(mim != address(0), "MIMLayerZeroScript: mim is not defined");
            indirectOFTV2 = LzIndirectOFTV2(
                deploy(
                    "MIM_IndirectOFTV2",
                    "LzIndirectOFTV2.sol:LzIndirectOFTV2",
                    abi.encode(mim, minterBurner, sharedDecimals, lzEndpoint, tx.origin)
                )
            );

            LzOFTV2FeeHandler feeHandler = LzOFTV2FeeHandler(
                payable(
                    deploy(
                        "MIM_FeeHandler",
                        "LzOFTV2FeeHandler.sol:LzOFTV2FeeHandler",
                        abi.encode(
                            tx.origin,
                            fixedFees[block.chainid],
                            address(indirectOFTV2),
                            address(0),
                            safe,
                            uint8(ILzFeeHandler.QuoteType.Fixed)
                        )
                    )
                )
            );

            if (indirectOFTV2.feeHandler() != feeHandler) {
                indirectOFTV2.setFeeHandler(feeHandler);
            }

            if (feeHandler.owner() != safe) {
                feeHandler.transferOwnership(safe);
            }

            if (!indirectOFTV2.useCustomAdapterParams()) {
                indirectOFTV2.setUseCustomAdapterParams(true);
            }

            /// @notice The layerzero token needs to be able to mint/burn anyswap tokens
            /// Only change the operator if the ownership is still the deployer
            if (
                !IOwnableOperators(address(minterBurner)).operators(address(indirectOFTV2)) &&
                BoringOwnable(address(minterBurner)).owner() == tx.origin
            ) {
                IOwnableOperators(address(minterBurner)).setOperator(address(indirectOFTV2), true);
            }

            if (!testing()) {
                if (Owned(mim).owner() != safe) {
                    Owned(mim).transferOwnership(safe);
                }
            }
        }

        vm.stopBroadcast();
    }
}
