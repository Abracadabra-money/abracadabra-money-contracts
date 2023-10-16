// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IBentoBoxV1.sol";
import "BoringSolidity/ERC20.sol";
import "utils/BaseScript.sol";
import "./SpellStakingRewardInfra.s.sol";

contract DegenBoxScript is BaseScript {
    using DeployerFunctions for Deployer;

    function deploy() public {
        // native wrapped token, called wETH for simplicity but could be wFTM on Fantom, wKAVA on KAVA etc.
        IERC20 weth = IERC20(toolkit.getAddress(block.chainid, "weth"));
        address safe = toolkit.getAddress(block.chainid, "safe.ops");

        IBentoBoxV1 degenBox = IBentoBoxV1(address(deployer.deploy_DegenBox(toolkit.prefixWithChainName(block.chainid, "DegenBox"), weth)));

        if (!testing()) {
            if (degenBox.owner() == tx.origin) {
                vm.broadcast();
                degenBox.transferOwnership(safe, true, false);
            }
        }
    }
}
