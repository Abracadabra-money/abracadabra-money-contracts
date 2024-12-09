// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {SdeusdPermissionedSwapper} from "/swappers/SdeusdPermissionedSwapper.sol";

contract SdeusdPermissionedSwapperScript is BaseScript {
    address public constant SDEUSD_CAULDRON_1 = 0x00380CB5858664078F2289180CC32F74440AC923;
    address public constant SDEUSD_CAULDRON_2 = 0x38E7D1e4E2dE5b06b6fc9A91C2c37828854A41bb;

    function deploy() public returns (SdeusdPermissionedSwapper) {
        address safe = toolkit.getAddress("safe.ops");
        address sdeusd = toolkit.getAddress("elixir.sdeusd");
        address mim = toolkit.getAddress("mim");
        
        vm.startBroadcast();
        OwnableOperators swapper = OwnableOperators(
            deploy("SdeusdPermissionedSwapper", "SdeusdPermissionedSwapper.sol:SdeusdPermissionedSwapper", abi.encode(sdeusd, mim, tx.origin))
        );

        if (!testing()) {
            if (!swapper.operators(SDEUSD_CAULDRON_1)) {
                swapper.setOperator(SDEUSD_CAULDRON_1, true);
            }
            if (!swapper.operators(SDEUSD_CAULDRON_2)) {
                swapper.setOperator(SDEUSD_CAULDRON_2, true);
            }
            if (swapper.owner() != safe) {
                swapper.transferOwnership(safe);
            }
        }

        vm.stopBroadcast();

        return SdeusdPermissionedSwapper(address(swapper));
    }
}
