// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "utils/CauldronDeployLib.sol";
import "periphery/Whitelister.sol";
import "cauldrons/WhitelistedCauldronV4.sol";

contract ProtocolOwnedFarming is BaseScript {
    function run() public returns (IOracle oracle) {
        if (block.chainid == ChainId.Mainnet) {
            IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
            ERC20 mim = ERC20(constants.getAddress("mainnet.mim"));
            address safe = constants.getAddress("mainnet.safe.ops");

            startBroadcast();

            oracle = IOracle(0xaBB326cD92b0e48fa6dfC54d69Cd1750a1007a97); // Stargate S-USDT Oracle
            CauldronV4 cauldronV4MC = new WhitelistedCauldronV4(degenBox, mim);

            WhitelistedCauldronV4 cauldron = WhitelistedCauldronV4(
                address(
                    CauldronDeployLib.deployCauldronV4(
                        degenBox,
                        address(cauldronV4MC),
                        IERC20(constants.getAddress("mainnet.stargate.usdtPool")),
                        oracle,
                        "",
                        9900, // 99% ltv
                        0, // 0% interests
                        0, // 0% opening
                        25 // 0.25% liquidation
                    )
                )
            );

            Whitelister whitelister = new Whitelister(bytes32(0), "");
            whitelister.setMaxBorrowOwner(safe, type(uint256).max);

            cauldron.changeWhitelister(whitelister);

            // Only when deploying live
            if (!testing) {
                cauldronV4MC.setFeeTo(safe);
                cauldronV4MC.transferOwnership(safe, true, false);
                whitelister.transferOwnership(safe, true, false);
            }

            stopBroadcast();
        }
    }
}
