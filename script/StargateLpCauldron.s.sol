// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "utils/CauldronDeployLib.sol";
import "oracles/ProxyOracle.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/ICauldronV4.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IERC4626.sol";
import "interfaces/IAggregator.sol";

contract StargateLpCauldronScript is BaseScript {
    using DeployerFunctions for Deployer;

    function deploy() public {
        if (block.chainid == ChainId.Kava) {
            _deployKavaStargateLPUSDT();
        } else {
            revert("Unsupported chain");
        }
    }

    function _deployKavaStargateLPUSDT() private {}
}
