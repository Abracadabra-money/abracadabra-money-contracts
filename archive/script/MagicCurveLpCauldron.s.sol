// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "utils/CauldronDeployLib.sol";
import "oracles/ProxyOracle.sol";
import "oracles/MagicVaultOracle.sol";
import "oracles/aggregators/CurveStablePoolAggregator.sol";
import "oracles/aggregators/XF33dAggregator.sol";
import "periphery/DegenBoxERC4626Wrapper.sol";
import "swappers/MagicCurveLpSwapper.sol";
import "swappers/MagicCurveLpLevSwapper.sol";
import "tokens/MagicCurveLp.sol";
import "periphery/MagicCurveLpHarvestor.sol";
import "periphery/MagicCurveLpRewardHandler.sol";
import "tokens/MagicCurveLp.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/ICurveRewardGauge.sol";
import "interfaces/ICauldronV4.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ICurvePool.sol";
import "interfaces/IERC4626.sol";
import "interfaces/IAggregator.sol";
import {IRedstoneAdapter} from "oracles/aggregators/RedstoneAggregator.sol";

contract MagicCurveLpScript is BaseScript {
    using DeployerFunctions for Deployer;

    address safe;
    address pool;
    address exchange;
    IBentoBoxV1 box;

    function deploy() public returns (MagicCurveLp vault, MagicCurveLpHarvestor harvestor) {
        if (block.chainid == ChainId.Kava) {
            vm.startBroadcast();
            CauldronDeployLib.deployCauldronV4(
                deployer,
                "Kava_MagicCurveLp_MIM_USDT_Cauldron",
                IBentoBoxV1(0x630FC1758De85C566Bdec1D75A894794E1819d7E),
                0x60bbeFE16DC584f9AF10138Da1dfbB4CDf25A097,
                IERC20(0x729D8855a1D21aB5F84dB80e00759E7149936e30),
                IOracle(0xBc7Fa554a65A98502457FCFC2f1afa28113D7920),
                "",
                9700, // 97% ltv
                300, // 3% interests
                15, // 0.15% opening
                50 // 0.5% liquidation
            );
            vm.stopBroadcast();

            return (MagicCurveLp(payable(address(0))), MagicCurveLpHarvestor(address(0)));
            //return _deployKavaMagicMimUsdt();
        } else {
            revert("Unsupported chain");
        }
    }

    function _deployKavaMagicMimUsdt() private returns (MagicCurveLp vault, MagicCurveLpHarvestor harvestor) {
        pool = toolkit.getAddress(block.chainid, "curve.mimusdt.pool");
        safe = toolkit.getAddress(block.chainid, "safe.ops");
        box = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        exchange = toolkit.getAddress(block.chainid, "aggregators.openocean");

        ICurveRewardGauge gauge = ICurveRewardGauge(toolkit.getAddress(block.chainid, "curve.mimusdt.gauge"));

        vault = MagicCurveLp(
            deployer.deploy_MagicCurveLp("Kava_MagicCurveLp_MIM_USDT", ERC20(pool), "magicCurveLP MIM-USDT", "mCurveLP-MIM-USDT")
        );

        MagicCurveLpRewardHandler rewardHandler = deployer.deploy_MagicCurveLpRewardHandler(
            "Kava_MagicCurveLpRewardHandler_MIM_USDT_Impl_V1"
        );

        if (vault.rewardHandler() != rewardHandler) {
            vm.broadcast();
            vault.setRewardHandler(rewardHandler);
        }

        if (MagicCurveLpRewardHandler(address(vault)).staking() != gauge) {
            vm.broadcast();
            MagicCurveLpRewardHandler(address(vault)).setStaking(gauge);
        }

        harvestor = deployer.deploy_MagicCurveLpHarvestor(
            "Kava_MagicCurveLpHarvestor_MIM_USDT_V1",
            IERC20(toolkit.getAddress(block.chainid, "wKava")),
            2, // MIM/USDT pool is 2 coins length
            1, // Provide liquidity using USDT (index: 1)
            vault
        );

        address routerAddress = toolkit.getAddress(block.chainid, "aggregators.openocean");
        if (harvestor.exchangeRouter() != routerAddress) {
            vm.broadcast();
            harvestor.setExchangeRouter(routerAddress);
        }

        if (IERC20(pool).allowance(address(harvestor), address(vault)) != type(uint256).max) {
            vm.broadcast();
            harvestor.setVaultAssetAllowance(type(uint256).max);
        }

        if (harvestor.feeCollector() != safe || harvestor.feeBips() != 100) {
            vm.broadcast();
            harvestor.setFeeParameters(safe, 100); // 1% fee
        }

        if (!vault.operators(address(harvestor))) {
            vm.broadcast();
            vault.setOperator(address(harvestor), true);
        }

        ProxyOracle oracle = ProxyOracle(deployer.deploy_ProxyOracle("Kava_MagicCurveLpProxyOracle_MIM_USDT"));

        IAggregator[] memory aggregators = new IAggregator[](1);

        aggregators[0] = IAggregator(toolkit.getAddress(ChainId.Kava, "redstone.usdt"));

        // pool: 0x591199E16E006Dec3eDcf79AE0fCea1Dd0F5b69D
        // redstone usdt: 0xc0c3B20Af1A431b9Ab4bfe1f396b12D97392e50f
        /*
            forge create --rpc-url https://evm.data.kava.chainstacklabs.com \
                --constructor-args 0x591199E16E006Dec3eDcf79AE0fCea1Dd0F5b69D "[0xc0c3B20Af1A431b9Ab4bfe1f396b12D97392e50f]"  \
                --private-key $PRIVATE_KEY \
                --verify --verifier blockscout --verifier-url https://kavascan.com/api? \
                --legacy \
                src/oracles/aggregators/CurveStablePoolAggregator.sol:CurveStablePoolAggregator
        */
        CurveStablePoolAggregator aggregator = CurveStablePoolAggregator(
            deployer.deploy_CurveStablePoolAggregator("Kava_Curve_MIM_USDT_Aggregator", ICurvePool(pool), aggregators)
        );

        // magicCurveLp MIM/USDT: 0x729D8855a1D21aB5F84dB80e00759E7149936e30
        // aggregator: 0xbA9167Fe9f0AC2DCB9A3A60870cAA5127A783A7E
        /*
            forge create --rpc-url https://evm.data.kava.chainstacklabs.com \
                --constructor-args "MagicCurveLP MIM-USDT Oracle" 0x729D8855a1D21aB5F84dB80e00759E7149936e30 0xbA9167Fe9f0AC2DCB9A3A60870cAA5127A783A7E \
                --private-key $PRIVATE_KEY \
                --verify --verifier blockscout --verifier-url https://kavascan.com/api? \
                --legacy \
                src/oracles/MagicVaultOracle.sol:MagicVaultOracle

            forge verify-contract --chain-id 2222 --num-of-optimizations 800 --watch \
                --constructor-args $(cast abi-encode "constructor(string,address,address)" "MagicCurveLP MIM-USDT Oracle" "0x729D8855a1D21aB5F84dB80e00759E7149936e30" "0xbA9167Fe9f0AC2DCB9A3A60870cAA5127A783A7E") \
                --compiler-version v0.8.20+commit.a1b79de6 0x6dA65013D5814dA632F1A94f3501aBc8e54C98ae src/oracles/MagicVaultOracle.sol:MagicVaultOracle \
                --verifier blockscout --verifier-url https://kavascan.com/api?
        */
        IOracle impl = deployer.deploy_MagicVaultOracle(
            "Kava_MagicCurveLpOracle_MIM_USDT",
            "MagicCurveLP MIM-USDT Oracle",
            IERC4626(address(vault)),
            aggregator
        );

        if (oracle.oracleImplementation() != impl) {
            vm.broadcast();
            oracle.changeOracleImplementation(impl);
        }

        /*
        vm.startBroadcast();
        CauldronDeployLib.deployCauldronV4(
            deployer,
            "Kava_MagicCurveLp_MIM_USDT_Cauldron",
            box,
            toolkit.getAddress(block.chainid, "cauldronV4"),
            IERC20(address(vault)),
            oracle,
            "",
            9800, // 98% ltv
            100, // 1% interests
            0, // 0% opening
            50 // 0.5% liquidation
        );
        vm.stopBroadcast();

        // DegenBoxERC4626Wrapper: 0x9b2794Aeff2E6Bd2b3e32e095E878bF17EB6BdCC
        /*
            forge create --rpc-url https://evm.data.kava.chainstacklabs.com \
                --constructor-args 0x630FC1758De85C566Bdec1D75A894794E1819d7E 0x729D8855a1D21aB5F84dB80e00759E7149936e30 \
                --private-key $PRIVATE_KEY \
                --verify --verifier blockscout --verifier-url https://kavascan.com/api? \
                --legacy \
                src/periphery/DegenBoxERC4626Wrapper.sol:DegenBoxERC4626Wrapper

            forge verify-contract --chain-id 2222 --num-of-optimizations 800 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address)" "0x630FC1758De85C566Bdec1D75A894794E1819d7E" "0x729D8855a1D21aB5F84dB80e00759E7149936e30") \
                --compiler-version v0.8.20+commit.a1b79de6 0x9b2794Aeff2E6Bd2b3e32e095E878bF17EB6BdCC src/periphery/DegenBoxERC4626Wrapper.sol:DegenBoxERC4626Wrapper \
                --verifier blockscout --verifier-url https://kavascan.com/api?
        */
        deployer.deploy_DegenBoxERC4626Wrapper("Kava_DegenBoxERC4626Wrapper_MagicCurveLP_MIM_USDT", box, vault);

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(ICurvePool(pool).coins(0));
        tokens[1] = IERC20(ICurvePool(pool).coins(1));

        // MagicCurveLpSwapper: 0xE427f03A5D41eb80d79F6D35B86f6fb7054a21a8
        /*
            forge create --rpc-url https://evm.data.kava.chainstacklabs.com \
                --constructor-args 0x630FC1758De85C566Bdec1D75A894794E1819d7E 0x729D8855a1D21aB5F84dB80e00759E7149936e30 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb 0 0x591199E16E006Dec3eDcf79AE0fCea1Dd0F5b69D 0x0000000000000000000000000000000000000000 "[0x471EE749bA270eb4c1165B5AD95E614947f6fCeb,0x919C1c267BC06a7039e03fcc2eF738525769109c]" 0x6352a56caadC4F1E25CD6c75970Fa768A3304e64 \
                --private-key $PRIVATE_KEY \
                --verify --verifier blockscout --verifier-url https://kavascan.com/api? \
                --legacy \
                src/swappers/MagicCurveLpSwapper.sol:MagicCurveLpSwapper

            forge verify-contract --chain-id 2222 --num-of-optimizations 800 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address,address,uint8,address,address,address[],address)" "0x630FC1758De85C566Bdec1D75A894794E1819d7E" "0x729D8855a1D21aB5F84dB80e00759E7149936e30" "0x471EE749bA270eb4c1165B5AD95E614947f6fCeb" 0 "0x591199E16E006Dec3eDcf79AE0fCea1Dd0F5b69D" "0x0000000000000000000000000000000000000000" "[0x471EE749bA270eb4c1165B5AD95E614947f6fCeb,0x919C1c267BC06a7039e03fcc2eF738525769109c]" "0x6352a56caadC4F1E25CD6c75970Fa768A3304e64") \
                --compiler-version v0.8.20+commit.a1b79de6 0xE427f03A5D41eb80d79F6D35B86f6fb7054a21a8 src/swappers/MagicCurveLpSwapper.sol:MagicCurveLpSwapper \
                --verifier blockscout --verifier-url https://kavascan.com/api?
        */
        deployer.deploy_MagicCurveLpSwapper(
            "Kava_MagicCurveLpSwapper_MIM_USDT",
            box,
            vault,
            IERC20(toolkit.getAddress(block.chainid, "mim")),
            CurvePoolInterfaceType.IFACTORY_POOL,
            pool,
            address(0),
            tokens,
            exchange
        );

        // MagicCurveLpLevSwapper: 0x29BE2644721689c45a5A317d5Fb452747E454DcE
        /*
            forge create --rpc-url https://evm.data.kava.chainstacklabs.com \
                --constructor-args 0x630FC1758De85C566Bdec1D75A894794E1819d7E 0x729D8855a1D21aB5F84dB80e00759E7149936e30 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb 2 0x591199E16E006Dec3eDcf79AE0fCea1Dd0F5b69D 0x0000000000000000000000000000000000000000 "[0x471EE749bA270eb4c1165B5AD95E614947f6fCeb,0x919C1c267BC06a7039e03fcc2eF738525769109c]" 0x6352a56caadC4F1E25CD6c75970Fa768A3304e64 \
                --private-key $PRIVATE_KEY \
                --verify --verifier blockscout --verifier-url https://kavascan.com/api? \
                --legacy \
                src/swappers/MagicCurveLpLevSwapper.sol:MagicCurveLpLevSwapper

            forge verify-contract --chain-id 2222 --num-of-optimizations 800 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address,address,uint8,address,address,address[],address)" "0x630FC1758De85C566Bdec1D75A894794E1819d7E" "0x729D8855a1D21aB5F84dB80e00759E7149936e30" "0x471EE749bA270eb4c1165B5AD95E614947f6fCeb" 2 "0x591199E16E006Dec3eDcf79AE0fCea1Dd0F5b69D" "0x0000000000000000000000000000000000000000" "[0x471EE749bA270eb4c1165B5AD95E614947f6fCeb,0x919C1c267BC06a7039e03fcc2eF738525769109c]" "0x6352a56caadC4F1E25CD6c75970Fa768A3304e64") \
                --compiler-version v0.8.20+commit.a1b79de6 0x29BE2644721689c45a5A317d5Fb452747E454DcE src/swappers/MagicCurveLpLevSwapper.sol:MagicCurveLpLevSwapper \
                --verifier blockscout --verifier-url https://kavascan.com/api?
        */
        deployer.deploy_MagicCurveLpLevSwapper(
            "Kava_MagicCurveLpLevSwapper_MIM_USDT",
            box,
            vault,
            IERC20(toolkit.getAddress(block.chainid, "mim")),
            CurvePoolInterfaceType.IFACTORY_POOL,
            pool,
            address(0),
            tokens,
            exchange
        );

        _transferOwnershipsAndMintInitial(pool, vault, harvestor, oracle);
    }

    function _transferOwnershipsAndMintInitial(
        address curvePool,
        MagicCurveLp vault,
        MagicCurveLpHarvestor harvestor,
        ProxyOracle oracle
    ) private {
        vm.startBroadcast();
        if (!testing()) {
            if (oracle.owner() != safe) {
                oracle.transferOwnership(safe, true, false);
            }
            if (vault.owner() != safe) {
                vault.transferOwnership(safe, true, false);
            }

            if (vault.totalSupply() == 0) {
                // mint some initial tokens
                ERC20(curvePool).approve(address(vault), ERC20(curvePool).balanceOf(tx.origin));
                vault.deposit(1 ether, safe);
            }

            // deployer needs to be operator of the vault since Gelato doesn't
            // support KAVA yet.
            if (!harvestor.operators(tx.origin)) {
                harvestor.setOperator(tx.origin, true);
            }
        }
        vm.stopBroadcast();
    }
}
