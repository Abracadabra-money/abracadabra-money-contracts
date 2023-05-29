// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "utils/StargateLib.sol";
import "periphery/CauldronFeeWithdrawer.sol";
import "periphery/MSpellSender.sol";
import "periphery/MSpellReporter.sol";
import "periphery/AnyswapCauldronFeeBridger.sol";

contract MSpellInfra is BaseScript {
    function deploy() public returns (MSpellSender sender) {
        startBroadcast();

        if (block.chainid == ChainId.Mainnet) {
            address safe = constants.getAddress("mainnet.safe.ops");

            CauldronFeeWithdrawer withdrawer = CauldronFeeWithdrawer(constants.getAddress("mainnet.cauldronFeeWithdrawer"));

            sender = new MSpellSender();
            sender.changePurchaser(0xdFE1a5b757523Ca6F7f049ac02151808E6A52111, constants.getAddress("mainnet.safe.ops"), 50); // InchSpellSwapper

            // mSpellStaking contracts
            sender.addMSpellRecipient(0xbD2fBaf2dc95bD78Cf1cD3c5235B33D1165E6797, ChainId.Mainnet, StargateChainId.Mainnet);
            sender.addMSpellRecipient(0xBd84472B31d947314fDFa2ea42460A2727F955Af, ChainId.Avalanche, StargateChainId.Avalanche);
            sender.addMSpellRecipient(0x1DF188958A8674B5177f77667b8D173c3CdD9e51, ChainId.Arbitrum, StargateChainId.Arbitrum);
            sender.addMSpellRecipient(0xa668762fb20bcd7148Db1bdb402ec06Eb6DAD569, ChainId.Fantom, StargateChainId.Fantom);

            sender.addReporter(
                StargateLib.getRecipient(constants.getAddress("avalanche.mspellReporter"), address(sender)),
                StargateChainId.Avalanche
            );
            sender.addReporter(
                StargateLib.getRecipient(constants.getAddress("arbitrum.mspellReporter"), address(sender)),
                StargateChainId.Arbitrum
            );
            sender.addReporter(
                StargateLib.getRecipient(constants.getAddress("fantom.mspellReporter"), address(sender)),
                StargateChainId.Fantom
            );

            sender.setWithdrawer(ICauldronFeeWithdrawer(address(withdrawer)));

            withdrawer.setOperator(address(sender), true);

            if (!testing) {
                sender.transferOwnership(safe, true, false);
                withdrawer.transferOwnership(safe, true, false);
            }
        }
        stopBroadcast();
    }
}
