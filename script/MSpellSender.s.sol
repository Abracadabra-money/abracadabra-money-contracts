// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "utils/LayerZeroLib.sol";
import "periphery/CauldronFeeWithdrawer.sol";
import "periphery/SpellStakingRewardDistributor.sol";

contract MSpellSenderScript is BaseScript {
    function deploy() public returns (SpellStakingRewardDistributor distributor) {
        if (block.chainid != ChainId.Mainnet) {
            revert("only mainnet");
        }

        startBroadcast();
        /*address safe = constants.getAddress("mainnet.safe.ops");

        CauldronFeeWithdrawer withdrawer = CauldronFeeWithdrawer(constants.getAddress("mainnet.cauldronFeeWithdrawer"));

        distributor = new SpellStakingRewardDistributor();
        distributor.changePurchaser(0xdFE1a5b757523Ca6F7f049ac02151808E6A52111, constants.getAddress("mainnet.safe.ops"), 50); // InchSpellSwapper

        // mSpellStaking contracts
        distributor.addMSpellRecipient(0xbD2fBaf2dc95bD78Cf1cD3c5235B33D1165E6797, ChainId.Mainnet, StargateChainId.Mainnet);
        distributor.addMSpellRecipient(0xBd84472B31d947314fDFa2ea42460A2727F955Af, ChainId.Avalanche, StargateChainId.Avalanche);
        distributor.addMSpellRecipient(0x1DF188958A8674B5177f77667b8D173c3CdD9e51, ChainId.Arbitrum, StargateChainId.Arbitrum);
        distributor.addMSpellRecipient(0xa668762fb20bcd7148Db1bdb402ec06Eb6DAD569, ChainId.Fantom, StargateChainId.Fantom);

        distributor.addReporter(
            StargateLib.getRecipient(constants.getAddress("avalanche.mspellReporter"), address(distributor)),
            StargateChainId.Avalanche
        );
        distributor.addReporter(
            StargateLib.getRecipient(constants.getAddress("arbitrum.mspellReporter"), address(distributor)),
            StargateChainId.Arbitrum
        );
        distributor.addReporter(
            StargateLib.getRecipient(constants.getAddress("fantom.mspellReporter"), address(distributor)),
            StargateChainId.Fantom
        );

        distributor.setWithdrawer(address(withdrawer));

        withdrawer.setOperator(address(sender), true);

        if (!testing) {
            distributor.transferOwnership(safe, true, false);
            withdrawer.transferOwnership(safe, true, false);
        }
*/
        stopBroadcast();
    }
}
