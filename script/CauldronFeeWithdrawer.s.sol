// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "utils/StargateLib.sol";
import "periphery/CauldronFeeWithdrawer.sol";
import "periphery/MSpellSender.sol";
import "periphery/MSpellReporter.sol";
import "periphery/AnyswapCauldronFeeBridger.sol";

contract CauldronFeeWithdrawerScript is BaseScript {
    function run() public returns (CauldronFeeWithdrawer withdrawer) {
        startBroadcast();

        if (block.chainid == ChainId.Mainnet) {
            IERC20 mim = IERC20(constants.getAddress("mainnet.mim"));
            address spell = constants.getAddress("mainnet.spell");
            address sSpell = constants.getAddress("mainnet.sSpell");
            address mimProvider = constants.getAddress("mainnet.safe.main");

            withdrawer = new CauldronFeeWithdrawer(mim);
            withdrawer.setParameters(
                constants.getAddress("mainnet.aggregators.zeroXExchangeProxy"),
                mimProvider,
                ICauldronFeeBridger(address(0))
            );

            withdrawer.setOperator(constants.getAddress("safe.devOps.gelatoProxy"), true);
            withdrawer.setSwapTokenOut(IERC20(spell), true);
            withdrawer.setSwappingRecipient(sSpell, true);

            withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("mainnet.sushiBentoBox")), true);
            withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("mainnet.degenBox")), true);

            if (!testing) {
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
        } else if (block.chainid == ChainId.Avalanche) {
            ERC20 mim = ERC20(constants.getAddress("avalanche.mim"));
            address mimProvider = constants.getAddress("avalanche.safe.ops");
            address safe = constants.getAddress("avalanche.safe.ops");

            withdrawer = new CauldronFeeWithdrawer(mim);
            withdrawer.setBridgeableToken(mim, true);
            withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("avalanche.degenBox1")), true);
            withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("avalanche.degenBox2")), true);

            AnyswapCauldronFeeBridger bridger = new AnyswapCauldronFeeBridger(
                IAnyswapRouter(constants.getAddress("avalanche.anyswapRouterV4")),
                constants.getAddress("mainnet.cauldronFeeWithdrawer"),
                ChainId.Mainnet
            );

            bridger.setOperator(address(withdrawer), true);
            withdrawer.setParameters(address(0), mimProvider, bridger);

            if (!testing) {
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

            mSpellReporter reporter = new mSpellReporter(
                ILayerZeroEndpoint(constants.getAddress("avalanche.LZendpoint")),
                IERC20(constants.getAddress("avalanche.spell")),
                constants.getAddress("avalanche.mspell"),
                safe
            );

            // Only when deploying live
            if (!testing) {
                withdrawer.transferOwnership(safe, true, false);
                bridger.transferOwnership(safe, true, false);
                reporter.transferOwnership(safe, true, false);
            }
        } else if (block.chainid == ChainId.Arbitrum) {
            return _deployArbitrumV2();
        } else if (block.chainid == ChainId.Fantom) {
            ERC20 mim = ERC20(constants.getAddress("fantom.mim"));
            address mimProvider = constants.getAddress("fantom.safe.main");
            address safe = constants.getAddress("fantom.safe.ops");

            withdrawer = new CauldronFeeWithdrawer(mim);
            withdrawer.setBridgeableToken(mim, true);
            withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("fantom.sushiBentoBox")), true);
            withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("fantom.degenBox")), true);

            AnyswapCauldronFeeBridger bridger = new AnyswapCauldronFeeBridger(
                IAnyswapRouter(constants.getAddress("fantom.anyswapRouterV4")),
                constants.getAddress("mainnet.cauldronFeeWithdrawer"),
                1
            );
            bridger.setOperator(address(withdrawer), true);
            withdrawer.setParameters(address(0), mimProvider, bridger);

            if (!testing) {
                CauldronInfo[] memory cauldronInfos = constants.getCauldrons("fantom", true);
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

            mSpellReporter reporter = new mSpellReporter(
                ILayerZeroEndpoint(constants.getAddress("fantom.LZendpoint")),
                IERC20(constants.getAddress("fantom.spell")),
                constants.getAddress("fantom.mspell"),
                safe
            );

            // Only when deploying live
            if (!testing) {
                withdrawer.transferOwnership(safe, true, false);
                bridger.transferOwnership(safe, true, false);
                reporter.transferOwnership(safe, true, false);
            }
        }

        stopBroadcast();
    }

    function _deployArbitrumV1() public returns (CauldronFeeWithdrawer withdrawer) {
        ERC20 mim = ERC20(constants.getAddress("arbitrum.mim"));
        address mimProvider = constants.getAddress("arbitrum.safe.main");
        address safe = constants.getAddress("arbitrum.safe.ops");

        withdrawer = new CauldronFeeWithdrawer(mim);
        withdrawer.setBridgeableToken(mim, true);
        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("arbitrum.sushiBentoBox")), true);
        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("arbitrum.degenBox")), true);

        AnyswapCauldronFeeBridger bridger = new AnyswapCauldronFeeBridger(
            IAnyswapRouter(constants.getAddress("arbitrum.anyswapRouterV4")),
            constants.getAddress("mainnet.cauldronFeeWithdrawer"),
            1
        );
        bridger.setOperator(address(withdrawer), true);
        withdrawer.setParameters(address(0), mimProvider, bridger);

        CauldronInfo[] memory cauldronInfos = constants.getCauldrons("arbitrum", true);
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

        mSpellReporter reporter = new mSpellReporter(
            ILayerZeroEndpoint(constants.getAddress("arbitrum.LZendpoint")),
            IERC20(constants.getAddress("arbitrum.spell")),
            constants.getAddress("arbitrum.mspell"),
            safe
        );

        if (!testing) {
            withdrawer.transferOwnership(safe, true, false);
            bridger.transferOwnership(safe, true, false);
            reporter.transferOwnership(safe, true, false);
        }
    }

    function _deployArbitrumV2() public returns (CauldronFeeWithdrawer withdrawer) {
        address safe = constants.getAddress("arbitrum.safe.ops");

        withdrawer = CauldronFeeWithdrawer(0xcF4f8E9A113433046B990980ebce5c3fA883067f);

        mSpellReporter reporter = new mSpellReporter(
            ILayerZeroEndpoint(constants.getAddress("arbitrum.LZendpoint")),
            IERC20(constants.getAddress("arbitrum.spell")),
            constants.getAddress("arbitrum.mspell"),
            safe
        );

        reporter.changeMSpellSender(constants.getAddress("mainnet.mSpellSender"));
        reporter.changeRefundTo(safe);

        if (!testing) {
            reporter.transferOwnership(safe, true, false);
        }
    }
}
