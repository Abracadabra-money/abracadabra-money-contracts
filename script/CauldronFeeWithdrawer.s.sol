// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "periphery/CauldronFeeWithdrawer.sol";
import "periphery/AnyswapCauldronFeeBridger.sol";

contract CauldronFeeWithdrawerScript is BaseScript {
    function run() public returns (CauldronFeeWithdrawer withdrawer) {
        address xMerlin = constants.getAddress("xMerlin");

        vm.startBroadcast();

        // Mainnet
        if (getChainIdKey() == ChainId.Mainnet) {
            ERC20 mim = ERC20(constants.getAddress("mainnet.mim"));
            address spell = constants.getAddress("mainnet.spell");
            address sSpell = constants.getAddress("mainnet.sSpell");
            address mimProvider = constants.getAddress("mainnet.mimProvider");

            withdrawer = new CauldronFeeWithdrawer(mim);
            withdrawer.setMimProvider(mimProvider);
            withdrawer.setSwappingRecipient(constants.getAddress("mainnet.sSpell"), true);
            withdrawer.setSwapper(constants.getAddress("mainnet.aggregators.zeroXExchangProxy"));
            withdrawer.setOperator(constants.getAddress("mainnet.devOps.gelatoProxy"), true);
            withdrawer.setSwapTokenOut(IERC20(spell), true);
            withdrawer.setSwappingRecipient(sSpell, true);

            withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("mainnet.sushiBentoBox")), true);
            withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("mainnet.degenBox")), true);

            CauldronInfo[] memory cauldronInfos = constants.getCauldrons("mainnet", true);
            address[] memory cauldrons = new address[](cauldronInfos.length);
            uint8[] memory versions = new uint8[](cauldronInfos.length);
            bool[] memory enabled = new bool[](cauldronInfos.length);

            for (uint256 i = 0; i < cauldronInfos.length; i++) {
                CauldronInfo memory cauldronInfo = cauldronInfos[i];
                cauldrons[i] = cauldronInfo.cauldron;
                versions[i] = cauldronInfo.version;
                enabled[i] = true;
            }

            withdrawer.setCauldrons(cauldrons, versions, enabled);
        }
        // Avalanche
        else if (getChainIdKey() == ChainId.Avalanche) {
            ERC20 mim = ERC20(constants.getAddress("avalanche.mim"));
            address mimProvider = constants.getAddress("avalanche.mimProvider");

            withdrawer = new CauldronFeeWithdrawer(mim);
            withdrawer.setMimProvider(mimProvider);
            withdrawer.setBridgeableToken(mim, true);
            withdrawer.setMimProvider(0x27C215c8b6e39f54C42aC04EB651211E9a566090);
            withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("avalanche.degenBox1")), true);
            withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("avalanche.degenBox2")), true);

            AnyswapCauldronFeeBridger bridger = new AnyswapCauldronFeeBridger(
                IAnyswapRouter(constants.getAddress("avalanche.anyswapRouterV4")),
                constants.getAddress("mainnet.cauldronFeeWithdrawer"),
                1
            );
            bridger.setAuthorizedCaller(address(withdrawer), true);
            withdrawer.setBridger(bridger);

            withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("avalanche.degenBox1")), true);
            withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("avalanche.degenBox2")), true);

            CauldronInfo[] memory cauldronInfos = constants.getCauldrons("avalanche", true);
            address[] memory cauldrons = new address[](cauldronInfos.length);
            uint8[] memory versions = new uint8[](cauldronInfos.length);
            bool[] memory enabled = new bool[](cauldronInfos.length);

            for (uint256 i = 0; i < cauldronInfos.length; i++) {
                CauldronInfo memory cauldronInfo = cauldronInfos[i];

                cauldrons[i] = cauldronInfo.cauldron;
                versions[i] = cauldronInfo.version;
                enabled[i] = true;
            }

            withdrawer.setCauldrons(cauldrons, versions, enabled);
        }

        // Only when deploying live
        if (!testing) {
            withdrawer.transferOwnership(xMerlin, true, false);
        }

        vm.stopBroadcast();
    }
}
