// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "interfaces/IMintableBurnable.sol";
contract DeployKavaMIMScript is BaseScript {
    using DeployerFunctions for Deployer;

    function deploy() public {
        IMintableBurnable(address(deployer.deploy_MintableBurnableERC20("KAVA_MIM", tx.origin, "Magic Internet Money", "MIM", 18)));
    }
}
