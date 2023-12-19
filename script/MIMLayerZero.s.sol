// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {IMintableBurnable} from "interfaces/IMintableBurnable.sol";
import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";
import {Operatable} from "mixins/Operatable.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ILzFeeHandler} from "interfaces/ILayerZero.sol";
import {LzProxyOFTV2} from "tokens/LzProxyOFTV2.sol";
import {LzIndirectOFTV2} from "tokens/LzIndirectOFTV2.sol";
import {LzOFTV2FeeHandler} from "periphery/LzOFTV2FeeHandler.sol";
import {ElevatedMinterBurner} from "periphery/ElevatedMinterBurner.sol";

contract MIMLayerZeroScript is BaseScript {
    mapping(uint256 => uint256) fixedFees;

    mapping(uint256 => bool) private _chainUsingAnyswap;
    mapping(uint256 => bool) private _chainUsingNativeFeeCollecting;

    function deploy() public returns (LzProxyOFTV2 proxyOFTV2, LzIndirectOFTV2 indirectOFTV2, IMintableBurnable minterBurner) {
        vm.startBroadcast();
        
        _chainUsingAnyswap[ChainId.BSC] = true;
        _chainUsingAnyswap[ChainId.Polygon] = true;
        _chainUsingAnyswap[ChainId.Fantom] = true;
        _chainUsingAnyswap[ChainId.Optimism] = true;
        _chainUsingAnyswap[ChainId.Arbitrum] = true;
        _chainUsingAnyswap[ChainId.Avalanche] = true;
        _chainUsingAnyswap[ChainId.Moonriver] = true;

        _chainUsingNativeFeeCollecting[ChainId.Base] = true;
        _chainUsingNativeFeeCollecting[ChainId.Linea] = true;
        _chainUsingNativeFeeCollecting[ChainId.Scroll] = true;

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
        fixedFees[534352] = 550000000000000;

        uint8 sharedDecimals = 8;
        address mim;
        address safe = toolkit.getAddress("safe.ops", block.chainid);
        address lzEndpoint = toolkit.getAddress("LZendpoint", block.chainid);

        if (block.chainid == ChainId.Mainnet) {
            mim = toolkit.getAddress("mim", block.chainid);
            proxyOFTV2 = LzProxyOFTV2(
                deploy("ProxyOFTV2", "LzProxyOFTV2.sol:LzProxyOFTV2", abi.encode(mim, sharedDecimals, lzEndpoint, tx.origin))
            );
            if (!proxyOFTV2.useCustomAdapterParams()) {
                proxyOFTV2.setUseCustomAdapterParams(true);
            }
        } else {
            if (_chainUsingAnyswap[block.chainid]) {
                mim = toolkit.getAddress("mim", block.chainid);
                minterBurner = ElevatedMinterBurner(
                    deploy("ElevatedMinterBurner", "ElevatedMinterBurner.sol:ElevatedMinterBurner", abi.encode(mim))
                );
            } else {
                // uses the same address for MIM and the minterBurner
                mim = address(
                    deploy(
                        "MIM",
                        "MintableBurnableERC20.sol:MintableBurnableERC20",
                        abi.encode(tx.origin, "Magic Internet Money", "MIM", 18)
                    )
                );
                minterBurner = IMintableBurnable(mim);
            }

            require(address(minterBurner) != address(0), "MIMLayerZeroScript: minterBurner is not defined");
            require(mim != address(0), "MIMLayerZeroScript: mim is not defined");

            indirectOFTV2 = LzIndirectOFTV2(
                deploy(
                    "IndirectOFTV2",
                    "LzIndirectOFTV2.sol:LzIndirectOFTV2",
                    abi.encode(mim, minterBurner, sharedDecimals, lzEndpoint, tx.origin)
                )
            );

            // Implementation where the fee handler is set directly n the proxy
            if (_chainUsingNativeFeeCollecting[block.chainid]) {
                LzOFTV2FeeHandler feeHandler = LzOFTV2FeeHandler(
                    payable(
                        deploy(
                            "FeeHandler",
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
            }

            if (!indirectOFTV2.useCustomAdapterParams()) {
                indirectOFTV2.setUseCustomAdapterParams(true);
            }

            /// @notice The layerzero token needs to be able to mint/burn anyswap tokens
            /// Only change the operator if the ownership is still the deployer
            if (
                !Operatable(address(minterBurner)).operators(address(indirectOFTV2)) &&
                BoringOwnable(address(minterBurner)).owner() == tx.origin
            ) {
                Operatable(address(minterBurner)).setOperator(address(indirectOFTV2), true);
            }

            if (!testing()) {
                if (Owned(mim).owner() != safe) {
                    Owned(mim).transferOwnership(safe);
                }
            }
        }

        vm.stopBroadcast();
    }

    function isChainUsingAnyswap(uint256 chainId) public view returns (bool) {
        return _chainUsingAnyswap[chainId];
    }
}
