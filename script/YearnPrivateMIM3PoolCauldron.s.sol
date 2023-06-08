// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "oracles/YearnCurveMeta3PoolOracle.sol";
import "utils/CauldronDeployLib.sol";
import "mixins/Whitelister.sol";

contract YearnPrivateMIM3PoolCauldronScript is BaseScript {
    using DeployerFunctions for Deployer;
    using CauldronDeployLib for Deployer;

    function deploy() public {
        if (block.chainid != ChainId.Mainnet) {
            revert("Unsupported chain");
        }
        deployer.setAutoBroadcast(false);
        startBroadcast();

        address safe = constants.getAddress("mainnet.safe.ops");

        ProxyOracle proxy = ProxyOracle(deployer.deploy_ProxyOracle("YearnCurveMeta3PoolProxyOracle"));
        IOracle oracle = IOracle(
            deployer.deploy_YearnCurveMeta3PoolOracle(
                "YearnCurveMeta3PoolOracle",
                IYearnVault(constants.getAddress("mainnet.yearn.mim3crv")),
                ICurveMeta3PoolOrale(0x80dB4F9e5A76554cc905ce15B6A5786f5C54c195), // CurveMeta3PoolOracle for MIM3CRV
                "Yearn MIM3CRV"
            )
        );

        deployer.deployCauldronV4(
            "YearnPrivateMIM3PoolCauldron2",
            IBentoBoxV1(constants.getAddress("mainnet.degenBox")),
            constants.getAddress("mainnet.cauldronV4Whitelisted"),
            IERC20(constants.getAddress("mainnet.yearn.mim3crv")),
            oracle,
            "",
            9900, // 98% ltv
            100, // 1% interests
            0, // 0% opening
            50 // 0.5% liquidation
        );

        /// @dev need to changeWhitelister to 0x4809CB637cd0592492be650A3d6EBD11c034e5CC
        /// once deployed.
        // cauldron.changeWhitelister(whitelister);

        if (oracle != proxy.oracleImplementation()) {
            proxy.changeOracleImplementation(oracle);
        }

        if (!testing) {
            if (proxy.owner() != safe) {
                proxy.transferOwnership(safe, true, false);
            }
        }

        stopBroadcast();
    }
}
