// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {ICauldronV1} from "interfaces/ICauldronV1.sol";
import {ICauldronV2} from "interfaces/ICauldronV2.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {OracleUpdater} from "periphery/OracleUpdater.sol";
import {CauldronRegistry} from "periphery/CauldronRegistry.sol";
import {MasterContractConfigurationRegistry, MasterContractConfiguration} from "periphery/MasterContractConfigurationRegistry.sol";

contract OracleUpdaterTest is Test {
    address registryOwner;
    CauldronRegistry cauldronRegistry;
    MasterContractConfigurationRegistry masterContractConfigurationRegistry;
    OracleUpdater oracleUpdater;

    function setUp() public {
        registryOwner = makeAddr("RegistryOwner");
        cauldronRegistry = new CauldronRegistry(registryOwner);
        masterContractConfigurationRegistry = new MasterContractConfigurationRegistry(registryOwner);
        oracleUpdater = new OracleUpdater(cauldronRegistry, masterContractConfigurationRegistry);
    }

    function mockCauldron(
        ICauldronV1 cauldron,
        ICauldronV1 masterContract,
        uint24 collaterizationRate,
        uint24 liquidationMultiplier,
        uint256 exchangeRate,
        IOracle oracle,
        uint256 oracleExchangeRate
    ) internal {
        vm.mockCall(address(cauldron), abi.encodeWithSelector(ICauldronV1.masterContract.selector), abi.encode(masterContract));
        vm.mockCall(address(cauldron), abi.encodeWithSelector(ICauldronV2.COLLATERIZATION_RATE.selector), abi.encode(collaterizationRate));
        vm.mockCall(
            address(cauldron),
            abi.encodeWithSelector(ICauldronV2.LIQUIDATION_MULTIPLIER.selector),
            abi.encode(liquidationMultiplier)
        );
        vm.mockCall(address(cauldron), abi.encodeWithSelector(ICauldronV1.exchangeRate.selector), abi.encode(exchangeRate));
        vm.mockCall(address(cauldron), abi.encodeWithSelector(ICauldronV1.oracleData.selector), abi.encode(0));
        vm.mockCall(address(cauldron), abi.encodeWithSelector(ICauldronV1.oracle.selector), abi.encode(oracle));
        vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.peek.selector), abi.encode(true, oracleExchangeRate));
        vm.mockCall(
            address(cauldron),
            abi.encodeWithSelector(ICauldronV1.updateExchangeRate.selector),
            abi.encode(exchangeRate != oracleExchangeRate, oracleExchangeRate)
        );
    }

    function testNonOverrideMasterContract() public {
        ICauldronV1 cauldron = ICauldronV1(makeAddr("Cauldron"));
        IOracle oracle = IOracle(makeAddr("Oracle"));
        uint24 collaterizationRate = 75000;
        uint24 liquidationMultiplier = 103000;
        mockCauldron(cauldron, ICauldronV1(makeAddr("MasterContract")), collaterizationRate, liquidationMultiplier, 10000, oracle, 100000);

        ICauldronV1[] memory cauldrons = new ICauldronV1[](1);
        cauldrons[0] = cauldron;
        vm.prank(registryOwner);
        cauldronRegistry.addCauldrons(cauldrons);

        vm.expectCall(address(cauldron), abi.encodeWithSelector(ICauldronV2.COLLATERIZATION_RATE.selector), 1);
        vm.expectCall(address(cauldron), abi.encodeWithSelector(ICauldronV2.LIQUIDATION_MULTIPLIER.selector), 1);

        (, bytes memory payload) = oracleUpdater.checker();
        (bool success, ) = address(oracleUpdater).call(payload);
        assertTrue(success);
    }

    function testOverrideMasterContract() public {
        ICauldronV1 cauldron = ICauldronV1(makeAddr("Cauldron"));
        IOracle oracle = IOracle(makeAddr("Oracle"));
        uint24 collaterizationRate = 75000;
        uint24 liquidationMultiplier = 103000;

        ICauldronV1[] memory masterContractArray = new ICauldronV1[](1);
        masterContractArray[0] = ICauldronV1(makeAddr("MasterContract"));

        MasterContractConfiguration[] memory masterContractConfigurationArray = new MasterContractConfiguration[](1);
        masterContractConfigurationArray[0] = MasterContractConfiguration(collaterizationRate, liquidationMultiplier);

        vm.prank(registryOwner);
        masterContractConfigurationRegistry.setConfigurations(masterContractArray, masterContractConfigurationArray);
        mockCauldron(cauldron, masterContractArray[0], collaterizationRate, liquidationMultiplier, 10000, oracle, 100000);

        ICauldronV1[] memory cauldrons = new ICauldronV1[](1);
        cauldrons[0] = cauldron;
        vm.prank(registryOwner);
        cauldronRegistry.addCauldrons(cauldrons);

        vm.expectCall(address(cauldron), abi.encodeWithSelector(ICauldronV2.COLLATERIZATION_RATE.selector), 0);
        vm.expectCall(address(cauldron), abi.encodeWithSelector(ICauldronV2.LIQUIDATION_MULTIPLIER.selector), 0);

        (, bytes memory payload) = oracleUpdater.checker();
        (bool success, ) = address(oracleUpdater).call(payload);
        assertTrue(success);
    }
}
