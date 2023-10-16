// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "oracles/YearnCurvePoolOracle.sol";
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
        vm.startBroadcast();

        address safe = toolkit.getAddress("mainnet.safe.ops");

        ProxyOracle oracle = ProxyOracle(deployer.deploy_ProxyOracle("YearnCurveMeta3PoolProxyOracle"));
        IOracle oracleImpl = IOracle(
            deployer.deploy_YearnCurvePoolOracle(
                "YearnCurveMeta3PoolOracle",
                IYearnVault(toolkit.getAddress("mainnet.yearn.mim3crv")),
                ICurveStablePoolAggregator(0x80dB4F9e5A76554cc905ce15B6A5786f5C54c195), // CurveStablePoolAggregator for MIM3CRV
                "Yearn MIM3CRV"
            )
        );

        deployer.deployCauldronV4(
            "YearnPrivateMIM3PoolCauldron",
            IBentoBoxV1(toolkit.getAddress("mainnet.degenBox")),
            toolkit.getAddress("mainnet.cauldronV4Whitelisted"),
            IERC20(toolkit.getAddress("mainnet.yearn.mim3crv")),
            oracle,
            "",
            9800, // 98% ltv
            100, // 1% interests
            0, // 0% opening
            50 // 0.5% liquidation
        );

        /// @dev need to changeWhitelister to 0x4809CB637cd0592492be650A3d6EBD11c034e5CC
        /// once deployed.
        // cauldron.changeWhitelister(whitelister);

        if (oracleImpl != oracle.oracleImplementation()) {
            oracle.changeOracleImplementation(oracleImpl);
        }

        if (!testing()) {
            if (oracle.owner() != safe) {
                oracle.transferOwnership(safe, true, false);
            }
        }

        vm.stopBroadcast();
    }
}
