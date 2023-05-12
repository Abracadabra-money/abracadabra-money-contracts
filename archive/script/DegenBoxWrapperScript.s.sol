// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "periphery/DegenBoxERC20VaultWrapper.sol";
import "periphery/DegenBoxERC4626Wrapper.sol";

contract DegenBoxWrapperScript is BaseScript {
    function deploy() public {
        startBroadcast();

        if (block.chainid == ChainId.Arbitrum) {
            new DegenBoxERC20VaultWrapper(
                IBentoBoxV1(constants.getAddress("arbitrum.degenBox")),
                IERC20Vault(constants.getAddress("arbitrum.abracadabraWrappedStakedGlp"))
            );
            new DegenBoxERC4626Wrapper(
                IBentoBoxV1(constants.getAddress("arbitrum.degenBox")),
                IERC4626(constants.getAddress("arbitrum.magicGlp"))
            );
        }

        if (block.chainid == ChainId.Optimism) {
            new DegenBoxERC20VaultWrapper(
                IBentoBoxV1(constants.getAddress("optimism.degenBox")),
                IERC20Vault(0x6Eb1709e0b562097BF1cc48Bc6A378446c297c04)
            );
        }

        stopBroadcast();
    }
}
