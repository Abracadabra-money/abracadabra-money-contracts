// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IBentoBoxV1.sol";
import "BoringSolidity/ERC20.sol";
import "utils/BaseScript.sol";

contract CauldronV4Script is BaseScript {
    using DeployerFunctions for Deployer;

    function deploy() public {
        IBentoBoxV1 degenBox = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        address safe = toolkit.getAddress(block.chainid, "safe.ops");
        ERC20 mim = ERC20(toolkit.getAddress(block.chainid, "mim"));

        CauldronOwner owner = deployer.deploy_CauldronOwner(toolkit.prefixWithChainName(block.chainid, "CauldronOwner"), safe, mim);
        CauldronV4 cauldronV4MC = deployer.deploy_CauldronV4(toolkit.prefixWithChainName(block.chainid, "CauldronV4"), degenBox, mim);

        vm.startBroadcast();
        if (!testing()) {
            owner.setOperator(safe, true);
            owner.transferOwnership(safe, true, false);
            cauldronV4MC.setFeeTo(safe);
            cauldronV4MC.transferOwnership(address(safe), true, false);
        }

        vm.stopBroadcast();
    }
}
