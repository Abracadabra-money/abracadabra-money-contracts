// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/BaseScript.sol";
import "cauldrons/CauldronV4.sol";
import "periphery/DegenBoxOwner.sol";
import "utils/CauldronLib.sol";
import "oracles/ProxyOracle.sol";
import "periphery/CauldronOwner.sol";

contract GlpCauldronScript is BaseScript {
    function run()
        public
        returns (
            CauldronV4 masterContract,
            DegenBoxOwner degenBoxOwner,
            ICauldronV4 cauldron
        )
    {
        vm.startBroadcast();

        if (block.chainid == ChainId.Mainnet) {
            IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
            masterContract = new CauldronV4(degenBox, IERC20(constants.getAddress("mainnet.mim")));
            degenBoxOwner = new DegenBoxOwner();
            degenBoxOwner.setDegenBox(degenBox);
        }

        if (block.chainid == ChainId.Arbitrum) {
            address safe = constants.getAddress("arbitrum.safe.main");
            ProxyOracle oracle = ProxyOracle(0x0E1eA2269D6e22DfEEbce7b0A4c6c3d415b5bC85);
            IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("arbitrum.degenBox"));
            masterContract = new CauldronV4(degenBox, IERC20(constants.getAddress("arbitrum.mim")));
            degenBoxOwner = new DegenBoxOwner();
            degenBoxOwner.setDegenBox(degenBox);

            IERC20 mim = IERC20(constants.getAddress("arbitrum.mim"));
            CauldronOwner owner = new CauldronOwner(safe, ERC20(address(mim)));
            CauldronV4 cauldronV4MC = new CauldronV4(degenBox, mim);

            cauldron = CauldronLib.deployCauldronV4(
                degenBox,
                address(cauldronV4MC),
                IERC20(constants.getAddress("arbitrum.gmx.glp")),
                oracle,
                "",
                7500, // 75% ltv
                200, // 2% interests
                50, // 0.5% opening
                750 // 7.5% liquidation
            );

            // Only when deploying live
            if (!testing) {
                owner.setOperator(safe, true);
                owner.transferOwnership(safe, true, false);
                cauldronV4MC.setFeeTo(safe);
                cauldronV4MC.transferOwnership(address(owner), true, false);
            }
        }

        vm.stopBroadcast();
    }
}
