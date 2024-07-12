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
import {FixedTokenExchange} from "periphery/FixedTokenExchange.sol";

contract SpellLayerZeroScript is BaseScript {
    bytes32 constant SPELL_FIXED_EXCHANGE_SALT = keccak256(bytes("Spell_FixedExchange_1720058322"));
    bytes32 constant SPELL_FEEHANDLER_SALT = keccak256(bytes("Spell_FeeHandler_1720058322"));
    bytes32 constant OFTV2_SALT = keccak256(bytes("Spell_OFTV2_1720058322"));

    function deploy() public returns (LzProxyOFTV2 proxyOFTV2, LzIndirectOFTV2 indirectOFTV2, address spell) {
        vm.startBroadcast();

        uint8 sharedDecimals = 8;
        address safe = toolkit.getAddress("safe.ops");
        address feeTo = toolkit.getAddress("safe.ops");
        address lzEndpoint = toolkit.getAddress("LZendpoint");

        if (block.chainid == ChainId.Mainnet) {
            spell = toolkit.getAddress("spell");

            proxyOFTV2 = LzProxyOFTV2(
                deployUsingCreate3(
                    "Spell_ProxyOFTV2",
                    OFTV2_SALT,
                    "LzProxyOFTV2.sol:LzProxyOFTV2",
                    abi.encode(spell, sharedDecimals, lzEndpoint, tx.origin)
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
            (indirectOFTV2, spell) = _deployIndirectOFTV2(sharedDecimals, lzEndpoint);
            LzOFTV2FeeHandler feeHandler = _deployFeeHandler(safe, feeTo, address(indirectOFTV2));

            if (indirectOFTV2.feeHandler() != feeHandler) {
                indirectOFTV2.setFeeHandler(feeHandler);
            }

            if (!indirectOFTV2.useCustomAdapterParams()) {
                indirectOFTV2.setUseCustomAdapterParams(true);
            }

            /// @notice The layerzero token needs to be able to mint/burn anyswap tokens
            /// Only change the operator if the ownership is still the deployer
            if (!Operatable(address(spell)).operators(address(indirectOFTV2)) && BoringOwnable(address(spell)).owner() == tx.origin) {
                Operatable(address(spell)).setOperator(address(indirectOFTV2), true);
            }

            FixedTokenExchange exchange = _deployOptionalTokenExchange(
                toolkit.getAddress(block.chainid, "spell") /* spellV1 */,
                spell /* spellV2 */
            );

            if (!testing()) {
                if (Owned(spell).owner() != safe) {
                    Owned(spell).transferOwnership(safe);
                }

                if (exchange != FixedTokenExchange(address(0)) && Owned(address(exchange)).owner() != safe) {
                    Owned(address(exchange)).transferOwnership(safe);
                }
            }
        }

        vm.stopBroadcast();
    }

    function _deployIndirectOFTV2(
        uint8 sharedDecimals,
        address lzEndpoint
    ) internal returns (LzIndirectOFTV2 indirectOFTV2, address spell) {
        spell = address(
            deploy("SPELL", "MintableBurnableERC20.sol:MintableBurnableERC20", abi.encode(tx.origin, "Spell Token", "SPELL", 18))
        );

        indirectOFTV2 = LzIndirectOFTV2(
            deployUsingCreate3(
                "Spell_IndirectOFTV2",
                OFTV2_SALT,
                "LzIndirectOFTV2.sol:LzIndirectOFTV2",
                abi.encode(spell, spell, sharedDecimals, lzEndpoint, tx.origin)
            )
        );
    }

    function _deployFeeHandler(address safe, address feeTo, address oft) internal returns (LzOFTV2FeeHandler feeHandler) {
        address oracle = toolkit.getAddress("oftv2.feehandler.oracle");

        feeHandler = LzOFTV2FeeHandler(
            payable(
                deployUsingCreate3(
                    "Spell_FeeHandler",
                    SPELL_FEEHANDLER_SALT,
                    "LzOFTV2FeeHandler.sol:LzOFTV2FeeHandler",
                    abi.encode(safe, 0, oft, address(oracle), feeTo, uint8(ILzFeeHandler.QuoteType.Oracle))
                )
            )
        );
    }

    /// @notice Optional spell v1 -> v2 token exchange
    function _deployOptionalTokenExchange(address spellV1, address spellV2) internal returns (FixedTokenExchange exchange) {
        if (block.chainid == ChainId.Fantom || block.chainid == ChainId.Arbitrum) {
            exchange = FixedTokenExchange(
                deployUsingCreate3(
                    "Spell_FixedExchange",
                    SPELL_FIXED_EXCHANGE_SALT,
                    "FixedTokenExchange.sol:FixedTokenExchange",
                    abi.encode(spellV1, spellV2, tx.origin),
                    0
                )
            );
        }
    }
}
