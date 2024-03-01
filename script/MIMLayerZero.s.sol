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
        _chainUsingNativeFeeCollecting[ChainId.Blast] = true;

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

                /*
                    forge verify-contract --num-of-optimizations 400 --watch \
                        --constructor-args $(cast abi-encode "constructor(address,string,string,uint8)" "0x0451ADD899D63Ba6A070333550137c3e9691De7d" "Magic Internet Money" "MIM" 18) \
                        --compiler-version v0.8.20+commit.a1b79de6 0x76DA31D7C9CbEAE102aff34D3398bC450c8374c1 src/tokens/MintableBurnableERC20.sol:MintableBurnableERC20 \
                        --verifier-url https://api.blastscan.io/api \
                        -e ${BLAST_ETHERSCAN_KEY}
                */
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

            /*
                forge verify-contract --num-of-optimizations 400 --watch \
                    --constructor-args $(cast abi-encode "constructor(address,address,uint8,address,address)" "0x76DA31D7C9CbEAE102aff34D3398bC450c8374c1" "0x76DA31D7C9CbEAE102aff34D3398bC450c8374c1" 8 "0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3") \
                    --compiler-version v0.8.20+commit.a1b79de6 0xcA8A205a579e06Cb1bE137EA3A5E5698C091f018 src/tokens/LzIndirectOFTV2.sol:LzIndirectOFTV2 \
                    --verifier-url https://api.blastscan.io/api \
                    -e ${BLAST_ETHERSCAN_KEY}
            */
            indirectOFTV2 = LzIndirectOFTV2(
                deploy(
                    "IndirectOFTV2",
                    "LzIndirectOFTV2.sol:LzIndirectOFTV2",
                    abi.encode(mim, minterBurner, sharedDecimals, lzEndpoint, tx.origin)
                )
            );

            // Implementation where the fee handler is set directly n the proxy
            if (_chainUsingNativeFeeCollecting[block.chainid]) {
                /*
                    forge verify-contract --num-of-optimizations 400 --watch \
                        --constructor-args $(cast abi-encode "constructor(address,uint256,address,address,address,uint8)" "0xfB3485c2e209A5cfBDC1447674256578f1A80eE3" 550000000000000 "0xcA8A205a579e06Cb1bE137EA3A5E5698C091f018" "0x0000000000000000000000000000000000000000" "0x0451ADD899D63Ba6A070333550137c3e9691De7d" 2) \
                        --compiler-version v0.8.20+commit.a1b79de6 0x630FC1758De85C566Bdec1D75A894794E1819d7E src/periphery/LzOFTV2FeeHandler.sol:LzOFTV2FeeHandler \
                        --verifier-url https://api.blastscan.io/api \
                        -e ${BLAST_ETHERSCAN_KEY}
                */
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
