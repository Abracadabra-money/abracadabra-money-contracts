// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {CauldronRegistry, CauldronInfo} from "periphery/CauldronRegistry.sol";
import {ICauldronV1} from "interfaces/ICauldronV1.sol";

contract CauldronRegistryTest is Test {
    address registryOwner;
    CauldronRegistry cauldronRegistry;

    function setUp() public {
        registryOwner = makeAddr("RegistryOwner");
        cauldronRegistry = new CauldronRegistry(registryOwner);
    }

    function testUniqueCauldron() public {
        vm.startPrank(registryOwner);

        CauldronInfo[] memory initialCauldrons = new CauldronInfo[](4);
        initialCauldrons[0] = CauldronInfo(makeAddr("Cauldron0"), 1, false);
        initialCauldrons[1] = CauldronInfo(makeAddr("Cauldron1"), 1, false);
        initialCauldrons[2] = CauldronInfo(makeAddr("Cauldron2"), 1, false);
        initialCauldrons[3] = CauldronInfo(makeAddr("Cauldron3"), 1, false);

        cauldronRegistry.add(initialCauldrons);

        for (uint256 i = 0; i < initialCauldrons.length; ++i) {
            CauldronInfo[] memory newCauldronArray = new CauldronInfo[](1);
            newCauldronArray[0] = initialCauldrons[i];

            vm.expectRevert(abi.encodeWithSelector(CauldronRegistry.ErrAlreadyRegistered.selector, initialCauldrons[i].cauldron));
            cauldronRegistry.add(newCauldronArray);
        }
    }

    function testCannotRegisterZeroAddress() public {
        vm.startPrank(registryOwner);

        CauldronInfo[] memory zeroAddressCauldronArray = new CauldronInfo[](1);
        zeroAddressCauldronArray[0] = CauldronInfo(address(0), 1, false);

        vm.expectRevert(abi.encodeWithSelector(CauldronRegistry.ErrInvalidCauldron.selector, address(0)));
        cauldronRegistry.add(zeroAddressCauldronArray);
    }

    function testTooManyCauldrons() public {
        vm.startPrank(registryOwner);

        CauldronInfo[] memory initialCauldrons = new CauldronInfo[](4);
        initialCauldrons[0] = CauldronInfo(makeAddr("Cauldron0"), 1, false);
        initialCauldrons[1] = CauldronInfo(makeAddr("Cauldron1"), 1, false);
        initialCauldrons[2] = CauldronInfo(makeAddr("Cauldron2"), 1, false);
        initialCauldrons[3] = CauldronInfo(makeAddr("Cauldron3"), 1, false);

        cauldronRegistry.add(initialCauldrons);

        address[] memory moreCauldrons = new address[](5);
        for (uint256 i = 0; i < initialCauldrons.length; ++i) {
            moreCauldrons[i] = initialCauldrons[i].cauldron;
        }
        moreCauldrons[4] = makeAddr("Cauldron4");

        vm.expectRevert(abi.encodeWithSelector(CauldronRegistry.ErrTooManyCauldrons.selector));
        cauldronRegistry.remove(moreCauldrons);
    }

    function testOnlyRemoveRegisteredCauldrons() public {
        vm.startPrank(registryOwner);

        address[] memory unregisteredCauldronArray = new address[](1);
        unregisteredCauldronArray[0] = makeAddr("UnregisteredCauldron");

        vm.expectRevert(abi.encodeWithSelector(CauldronRegistry.ErrEmptyRegistry.selector));
        cauldronRegistry.remove(unregisteredCauldronArray);

        CauldronInfo[] memory initialCauldrons = new CauldronInfo[](4);
        initialCauldrons[0] = CauldronInfo(makeAddr("Cauldron0"), 1, false);
        initialCauldrons[1] = CauldronInfo(makeAddr("Cauldron1"), 1, false);
        initialCauldrons[2] = CauldronInfo(makeAddr("Cauldron2"), 1, false);
        initialCauldrons[3] = CauldronInfo(makeAddr("Cauldron3"), 1, false);

        cauldronRegistry.add(initialCauldrons);

        vm.expectRevert(abi.encodeWithSelector(CauldronRegistry.ErrNotRegistered.selector, unregisteredCauldronArray[0]));
        cauldronRegistry.remove(unregisteredCauldronArray);
    }

    function testAddRemoveCauldrons() public {
        vm.startPrank(registryOwner);

        CauldronInfo[] memory initialCauldrons = new CauldronInfo[](10);
        initialCauldrons[0] = CauldronInfo(makeAddr("Cauldron0"), 1, false);
        initialCauldrons[1] = CauldronInfo(makeAddr("Cauldron1"), 1, false);
        initialCauldrons[2] = CauldronInfo(makeAddr("Cauldron2"), 1, false);
        initialCauldrons[3] = CauldronInfo(makeAddr("Cauldron3"), 1, false);
        initialCauldrons[4] = CauldronInfo(makeAddr("Cauldron4"), 1, false);
        initialCauldrons[5] = CauldronInfo(makeAddr("Cauldron5"), 1, false);
        initialCauldrons[6] = CauldronInfo(makeAddr("Cauldron6"), 1, false);
        initialCauldrons[7] = CauldronInfo(makeAddr("Cauldron7"), 1, false);
        initialCauldrons[8] = CauldronInfo(makeAddr("Cauldron8"), 1, false);
        initialCauldrons[9] = CauldronInfo(makeAddr("Cauldron9"), 1, false);

        cauldronRegistry.add(initialCauldrons);

        assertEq(cauldronRegistry.length(), 10);
        assertEq(cauldronRegistry.get(0).cauldron, initialCauldrons[0].cauldron);
        assertEq(cauldronRegistry.get(1).cauldron, initialCauldrons[1].cauldron);
        assertEq(cauldronRegistry.get(2).cauldron, initialCauldrons[2].cauldron);
        assertEq(cauldronRegistry.get(3).cauldron, initialCauldrons[3].cauldron);
        assertEq(cauldronRegistry.get(4).cauldron, initialCauldrons[4].cauldron);
        assertEq(cauldronRegistry.get(5).cauldron, initialCauldrons[5].cauldron);
        assertEq(cauldronRegistry.get(6).cauldron, initialCauldrons[6].cauldron);
        assertEq(cauldronRegistry.get(7).cauldron, initialCauldrons[7].cauldron);
        assertEq(cauldronRegistry.get(8).cauldron, initialCauldrons[8].cauldron);
        assertEq(cauldronRegistry.get(9).cauldron, initialCauldrons[9].cauldron);

        address[] memory lastCauldronArray = new address[](1);
        lastCauldronArray[0] = initialCauldrons[9].cauldron;
        cauldronRegistry.remove(lastCauldronArray);

        assertEq(cauldronRegistry.length(), 9);
        assertEq(cauldronRegistry.get(0).cauldron, initialCauldrons[0].cauldron);
        assertEq(cauldronRegistry.get(1).cauldron, initialCauldrons[1].cauldron);
        assertEq(cauldronRegistry.get(2).cauldron, initialCauldrons[2].cauldron);
        assertEq(cauldronRegistry.get(3).cauldron, initialCauldrons[3].cauldron);
        assertEq(cauldronRegistry.get(4).cauldron, initialCauldrons[4].cauldron);
        assertEq(cauldronRegistry.get(5).cauldron, initialCauldrons[5].cauldron);
        assertEq(cauldronRegistry.get(6).cauldron, initialCauldrons[6].cauldron);
        assertEq(cauldronRegistry.get(7).cauldron, initialCauldrons[7].cauldron);
        assertEq(cauldronRegistry.get(8).cauldron, initialCauldrons[8].cauldron);

        address[] memory firstCauldronArray = new address[](1);
        firstCauldronArray[0] = initialCauldrons[0].cauldron;
        cauldronRegistry.remove(firstCauldronArray);

        assertEq(cauldronRegistry.length(), 8);
        assertEq(cauldronRegistry.get(0).cauldron, initialCauldrons[8].cauldron);
        assertEq(cauldronRegistry.get(1).cauldron, initialCauldrons[1].cauldron);
        assertEq(cauldronRegistry.get(2).cauldron, initialCauldrons[2].cauldron);
        assertEq(cauldronRegistry.get(3).cauldron, initialCauldrons[3].cauldron);
        assertEq(cauldronRegistry.get(4).cauldron, initialCauldrons[4].cauldron);
        assertEq(cauldronRegistry.get(5).cauldron, initialCauldrons[5].cauldron);
        assertEq(cauldronRegistry.get(6).cauldron, initialCauldrons[6].cauldron);
        assertEq(cauldronRegistry.get(7).cauldron, initialCauldrons[7].cauldron);

        CauldronInfo[] memory newLastCauldronArray = new CauldronInfo[](1);
        newLastCauldronArray[0] = initialCauldrons[9];
        cauldronRegistry.add(newLastCauldronArray);

        assertEq(cauldronRegistry.length(), 9);
        assertEq(cauldronRegistry.get(0).cauldron, initialCauldrons[8].cauldron);
        assertEq(cauldronRegistry.get(1).cauldron, initialCauldrons[1].cauldron);
        assertEq(cauldronRegistry.get(2).cauldron, initialCauldrons[2].cauldron);
        assertEq(cauldronRegistry.get(3).cauldron, initialCauldrons[3].cauldron);
        assertEq(cauldronRegistry.get(4).cauldron, initialCauldrons[4].cauldron);
        assertEq(cauldronRegistry.get(5).cauldron, initialCauldrons[5].cauldron);
        assertEq(cauldronRegistry.get(6).cauldron, initialCauldrons[6].cauldron);
        assertEq(cauldronRegistry.get(7).cauldron, initialCauldrons[7].cauldron);
        assertEq(cauldronRegistry.get(8).cauldron, initialCauldrons[9].cauldron);

        address[] memory middleCauldrons = new address[](3);
        middleCauldrons[0] = initialCauldrons[3].cauldron;
        middleCauldrons[1] = initialCauldrons[4].cauldron;
        middleCauldrons[2] = initialCauldrons[5].cauldron;

        cauldronRegistry.remove(middleCauldrons);

        assertEq(cauldronRegistry.length(), 6);
        assertEq(cauldronRegistry.get(0).cauldron, initialCauldrons[8].cauldron);
        assertEq(cauldronRegistry.get(1).cauldron, initialCauldrons[1].cauldron);
        assertEq(cauldronRegistry.get(2).cauldron, initialCauldrons[2].cauldron);
        assertEq(cauldronRegistry.get(3).cauldron, initialCauldrons[9].cauldron);
        assertEq(cauldronRegistry.get(4).cauldron, initialCauldrons[7].cauldron);
        assertEq(cauldronRegistry.get(5).cauldron, initialCauldrons[6].cauldron);

        uint256 currentlength = cauldronRegistry.length();
        address[] memory currentCauldrons = new address[](currentlength);
        for (uint256 i = 0; i < currentlength; ++i) {
            currentCauldrons[i] = cauldronRegistry.get(i).cauldron;
        }
        cauldronRegistry.remove(currentCauldrons);

        assertEq(cauldronRegistry.length(), 0);

        cauldronRegistry.add(initialCauldrons);

        assertEq(cauldronRegistry.get(0).cauldron, initialCauldrons[0].cauldron);
        assertEq(cauldronRegistry.get(1).cauldron, initialCauldrons[1].cauldron);
        assertEq(cauldronRegistry.get(2).cauldron, initialCauldrons[2].cauldron);
        assertEq(cauldronRegistry.get(3).cauldron, initialCauldrons[3].cauldron);
        assertEq(cauldronRegistry.get(4).cauldron, initialCauldrons[4].cauldron);
        assertEq(cauldronRegistry.get(5).cauldron, initialCauldrons[5].cauldron);
        assertEq(cauldronRegistry.get(6).cauldron, initialCauldrons[6].cauldron);
        assertEq(cauldronRegistry.get(7).cauldron, initialCauldrons[7].cauldron);
        assertEq(cauldronRegistry.get(8).cauldron, initialCauldrons[8].cauldron);
        assertEq(cauldronRegistry.get(9).cauldron, initialCauldrons[9].cauldron);
    }

    function testSetDepracated() public {
        vm.startPrank(registryOwner);

        CauldronInfo[] memory initialCauldrons = new CauldronInfo[](4);
        initialCauldrons[0] = CauldronInfo(makeAddr("Cauldron0"), 1, false);
        initialCauldrons[1] = CauldronInfo(makeAddr("Cauldron1"), 1, false);
        initialCauldrons[2] = CauldronInfo(makeAddr("Cauldron2"), 1, false);
        initialCauldrons[3] = CauldronInfo(makeAddr("Cauldron3"), 1, false);

        cauldronRegistry.add(initialCauldrons);

        cauldronRegistry.setDeprecated(initialCauldrons[0].cauldron, true);
        assertEq(cauldronRegistry.get(0).deprecated, true);

        cauldronRegistry.setDeprecated(initialCauldrons[0].cauldron, false);
        assertEq(cauldronRegistry.get(0).deprecated, false);
    }
}
