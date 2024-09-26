// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Owned} from "@solmate/auth/Owned.sol";
import {BoringOwnable} from "@BoringSolidity/BoringOwnable.sol";
import "utils/BaseScript.sol";
import {IMintableBurnable} from "/interfaces/IMintableBurnable.sol";
import {ILzFeeHandler} from "@abracadabra-oftv2/interfaces/ILayerZero.sol";
import {LzProxyOFTV2} from "@abracadabra-oftv2/LzProxyOFTV2.sol";
import {LzIndirectOFTV2} from "@abracadabra-oftv2/LzIndirectOFTV2.sol";
import {LzOFTV2FeeHandler} from "/periphery/LzOFTV2FeeHandler.sol";
import {TokenMigrator} from "/periphery/TokenMigrator.sol";
import {IOwnableOperators} from "/interfaces/IOwnableOperators.sol";
import {BSPELL_SALT} from "script/BoundSpell.s.sol";

contract BoundSpellLayerZeroScript is BaseScript {
    bytes32 constant BOUNDSPELL_FEEHANDLER_SALT = keccak256(bytes("BoundSpell_FeeHandler_1727105731"));
    bytes32 constant OFTV2_SALT = keccak256(bytes("BoundSpell_OFTV2_1727105731"));

    function deploy() public {
        vm.startBroadcast();

        uint8 sharedDecimals = 8;
        address safe = toolkit.getAddress("safe.ops");
        address feeTo = toolkit.getAddress("safe.yields");
        address lzEndpoint = toolkit.getAddress("LZendpoint");
        address bSpell = toolkit.getAddress("bSpell");

        if (block.chainid == ChainId.Arbitrum) {
            LzProxyOFTV2 proxyOFTV2 = LzProxyOFTV2(
                deployUsingCreate3(
                    "BoundSPELL_ProxyOFTV2",
                    OFTV2_SALT,
                    "LzProxyOFTV2.sol:LzProxyOFTV2",
                    abi.encode(bSpell, sharedDecimals, lzEndpoint, tx.origin)
                )
            );

            LzOFTV2FeeHandler feeHandler = _deployFeeHandler(safe, feeTo, address(proxyOFTV2));

            if (proxyOFTV2.feeHandler() != feeHandler) {
                proxyOFTV2.setFeeHandler(feeHandler);
            }

            if (!proxyOFTV2.useCustomAdapterParams()) {
                proxyOFTV2.setUseCustomAdapterParams(true);
            }
        } else {
            LzIndirectOFTV2 indirectOFTV2 = LzIndirectOFTV2(
                deployUsingCreate3(
                    "BoundSPELL_IndirectOFTV2",
                    OFTV2_SALT,
                    "LzIndirectOFTV2.sol:LzIndirectOFTV2",
                    abi.encode(bSpell, bSpell, sharedDecimals, lzEndpoint, tx.origin)
                )
            );

            LzOFTV2FeeHandler feeHandler = _deployFeeHandler(safe, feeTo, address(indirectOFTV2));

            if (indirectOFTV2.feeHandler() != feeHandler) {
                indirectOFTV2.setFeeHandler(feeHandler);
            }

            if (!indirectOFTV2.useCustomAdapterParams()) {
                indirectOFTV2.setUseCustomAdapterParams(true);
            }

            if (
                !IOwnableOperators(address(bSpell)).operators(address(indirectOFTV2)) && BoringOwnable(address(bSpell)).owner() == tx.origin
            ) {
                IOwnableOperators(address(bSpell)).setOperator(address(indirectOFTV2), true);
            }

            if (!testing()) {
                if (Owned(bSpell).owner() != safe) {
                    Owned(bSpell).transferOwnership(safe);
                }
            }
        }

        vm.stopBroadcast();
    }

    function _deployFeeHandler(address safe, address feeTo, address oft) internal returns (LzOFTV2FeeHandler feeHandler) {
        address oracle = toolkit.getAddress("oftv2.feehandler.oracle");

        feeHandler = LzOFTV2FeeHandler(
            payable(
                deployUsingCreate3(
                    "BoundSPELL_FeeHandler",
                    BOUNDSPELL_FEEHANDLER_SALT,
                    "LzOFTV2FeeHandler.sol:LzOFTV2FeeHandler",
                    abi.encode(safe, 0, oft, address(oracle), feeTo, uint8(ILzFeeHandler.QuoteType.Oracle))
                )
            )
        );
    }
}
