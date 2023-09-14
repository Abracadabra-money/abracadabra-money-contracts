// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "utils/CauldronDeployLib.sol";
import "oracles/ProxyOracle.sol";
import "tokens/MagicStargateLp.sol";
import "periphery/MagicStargateLpHarvestor.sol";
import "periphery/MagicStargateLpRewardHandler.sol";
import "tokens/MagicStargateLp.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/ICauldronV4.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IERC4626.sol";
import "interfaces/IAggregator.sol";

contract StargateLpCauldronScript is BaseScript {
    using DeployerFunctions for Deployer;

    address safe;
    address pool;
    address exchange;
    IBentoBoxV1 box;

    function deploy() public returns (MagicStargateLp vault, MagicStargateLpHarvestor harvestor) {
        if (block.chainid == ChainId.Kava) {
            return _deployKavaUSDT();
        } else {
            revert("Unsupported chain");
        }
    }

    function _deployKavaUSDT() private returns (MagicStargateLp vault, MagicStargateLpHarvestor harvestor) {
        pool = toolkit.getAddress(block.chainid, "curve.mimusdt.pool");
        safe = toolkit.getAddress(block.chainid, "safe.ops");
        box = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        exchange = toolkit.getAddress(block.chainid, "aggregators.openocean");
    }
}
