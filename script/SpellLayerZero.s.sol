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

contract SpellLayerZeroScript is BaseScript {
    function deploy() public returns (LzProxyOFTV2 proxyOFTV2, LzIndirectOFTV2 indirectOFTV2, address spell) {
        vm.startBroadcast();

        uint8 sharedDecimals = 8;
        address safe = toolkit.getAddress("safe.ops", block.chainid);
        address feeTo = toolkit.getAddress("safe.ops", block.chainid);
        address lzEndpoint = toolkit.getAddress(block.chainid, "LZendpoint");

        if (block.chainid == ChainId.Mainnet) {
            spell = toolkit.getAddress(block.chainid, "spell");

            proxyOFTV2 = LzProxyOFTV2(
                deploy("Spell_ProxyOFTV2", "LzProxyOFTV2.sol:LzProxyOFTV2", abi.encode(spell, sharedDecimals, lzEndpoint, tx.origin))
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
            if (
                !Operatable(address(spell)).operators(address(indirectOFTV2)) &&
                BoringOwnable(address(spell)).owner() == tx.origin
            ) {
                Operatable(address(spell)).setOperator(address(indirectOFTV2), true);
            }

            if (!testing()) {
                if (Owned(spell).owner() != safe) {
                    Owned(spell).transferOwnership(safe);
                }
            }
        }

        vm.stopBroadcast();
    }

    function _deployIndirectOFTV2(
        uint8 sharedDecimals,
        address lzEndpoint
    ) internal returns (LzIndirectOFTV2 indirectOFTV2, address spell) {
        if (block.chainid == ChainId.Blast) {
            address blastGovernor = toolkit.getAddress(ChainId.Blast, "blastGovernor");

            spell = address(
                deploy(
                    "SPELL",
                    "BlastMintableBurnableERC20.sol:BlastMintableBurnableERC20",
                    abi.encode(tx.origin, "Spell Token", "SPELL", 18, blastGovernor)
                )
            );

            indirectOFTV2 = LzIndirectOFTV2(
                deploy(
                    "Spell_IndirectOFTV2",
                    "BlastLzIndirectOFTV2.sol:BlastLzIndirectOFTV2",
                    abi.encode(spell, spell, sharedDecimals, lzEndpoint, tx.origin, blastGovernor)
                )
            );
        } else {
            spell = address(
                deploy("SPELL", "MintableBurnableERC20.sol:MintableBurnableERC20", abi.encode(tx.origin, "Spell Token", "SPELL", 18))
            );

            indirectOFTV2 = LzIndirectOFTV2(
                deploy(
                    "Spell_IndirectOFTV2",
                    "LzIndirectOFTV2.sol:LzIndirectOFTV2",
                    abi.encode(spell, spell, sharedDecimals, lzEndpoint, tx.origin)
                )
            );
        }
    }

    function _deployFeeHandler(address safe, address feeTo, address oft) internal returns (LzOFTV2FeeHandler feeHandler) {
        address oracle = toolkit.getAddress("oftv2.feehandler.oracle", block.chainid);

        if (block.chainid == ChainId.Blast) {
            address blastGovernor = toolkit.getAddress(ChainId.Blast, "blastGovernor");

            feeHandler = LzOFTV2FeeHandler(
                payable(
                    deploy(
                        "Spell_FeeHandler",
                        "BlastLzOFTV2FeeHandler.sol:BlastLzOFTV2FeeHandler",
                        abi.encode(safe, 0, oft, address(oracle), feeTo, uint8(ILzFeeHandler.QuoteType.Oracle), blastGovernor)
                    )
                )
            );
        } else {
            feeHandler = LzOFTV2FeeHandler(
                payable(
                    deploy(
                        "Spell_FeeHandler",
                        "LzOFTV2FeeHandler.sol:LzOFTV2FeeHandler",
                        abi.encode(safe, 0, oft, address(oracle), feeTo, uint8(ILzFeeHandler.QuoteType.Oracle))
                    )
                )
            );
        }
    }
}
