// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {MasterContractConfigurationRegistry, MasterContractConfiguration} from "periphery/MasterContractConfigurationRegistry.sol";
import {ICauldronV1} from "interfaces/ICauldronV1.sol";

contract MasterContractConfigurationRegistryTest is Test {
    address registryOwner;
    MasterContractConfigurationRegistry masterContractConfigurationRegistry;

    function setUp() public {
        registryOwner = makeAddr("RegistryOwner");
        masterContractConfigurationRegistry = new MasterContractConfigurationRegistry(registryOwner);
    }

    function testAddRemoveConfigurations() public {
        vm.startPrank(registryOwner);

        ICauldronV1[] memory masterContracts = new ICauldronV1[](4);
        masterContracts[0] = ICauldronV1(makeAddr("MasterContract0"));
        masterContracts[1] = ICauldronV1(makeAddr("MasterContract1"));
        masterContracts[2] = ICauldronV1(makeAddr("MasterContract2"));
        masterContracts[3] = ICauldronV1(makeAddr("MasterContract3"));

        MasterContractConfiguration[] memory configurations = new MasterContractConfiguration[](4);
        configurations[0] = MasterContractConfiguration(75000, 106000);
        configurations[1] = MasterContractConfiguration(80000, 105000);
        configurations[2] = MasterContractConfiguration(85000, 104000);
        configurations[3] = MasterContractConfiguration(90000, 102000);

        masterContractConfigurationRegistry.setConfigurations(masterContracts, configurations);

        uint24 collaterizationRate;
        uint24 liquidationMultiplier;
        for (uint256 i = 0; i < masterContracts.length; ++i) {
            (collaterizationRate, liquidationMultiplier) = masterContractConfigurationRegistry.configurations(masterContracts[i]);
            assertEq(collaterizationRate, configurations[i].collaterizationRate);
            assertEq(liquidationMultiplier, configurations[i].liquidationMultiplier);
        }

        ICauldronV1[] memory firstMasterContractArray = new ICauldronV1[](1);
        firstMasterContractArray[0] = masterContracts[0];

        masterContractConfigurationRegistry.removeConfigurations(firstMasterContractArray);

        (collaterizationRate, liquidationMultiplier) = masterContractConfigurationRegistry.configurations(masterContracts[0]);
        assertEq(collaterizationRate, 0);
        assertEq(liquidationMultiplier, 0);

        for (uint256 i = 1; i < masterContracts.length; ++i) {
            (collaterizationRate, liquidationMultiplier) = masterContractConfigurationRegistry.configurations(masterContracts[i]);
            assertEq(collaterizationRate, configurations[i].collaterizationRate);
            assertEq(liquidationMultiplier, configurations[i].liquidationMultiplier);
        }

        MasterContractConfiguration[] memory firstConfigurationArray = new MasterContractConfiguration[](1);
        firstConfigurationArray[0] = configurations[0];

        masterContractConfigurationRegistry.setConfigurations(firstMasterContractArray, firstConfigurationArray);

        for (uint256 i = 0; i < masterContracts.length; ++i) {
            (collaterizationRate, liquidationMultiplier) = masterContractConfigurationRegistry.configurations(masterContracts[i]);
            assertEq(collaterizationRate, configurations[i].collaterizationRate);
            assertEq(liquidationMultiplier, configurations[i].liquidationMultiplier);
        }
    }

    function testMustHaveSameLength() public {
        vm.startPrank(registryOwner);

        ICauldronV1[] memory masterContracts = new ICauldronV1[](2);
        masterContracts[0] = ICauldronV1(makeAddr("MasterContract0"));
        masterContracts[1] = ICauldronV1(makeAddr("MasterContract1"));

        MasterContractConfiguration[] memory configurations = new MasterContractConfiguration[](1);
        configurations[0] = MasterContractConfiguration(75000, 103000);

        vm.expectRevert(abi.encodeWithSelector(MasterContractConfigurationRegistry.ErrLengthMismatch.selector));
        masterContractConfigurationRegistry.setConfigurations(masterContracts, configurations);
    }
}
