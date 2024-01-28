// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {CauldronRegistry} from "periphery/CauldronRegistry.sol";
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

        ICauldronV1[] memory initalCauldrons = new ICauldronV1[](4);
        initalCauldrons[0] = ICauldronV1(makeAddr("Cauldron0"));
        initalCauldrons[1] = ICauldronV1(makeAddr("Cauldron1"));
        initalCauldrons[2] = ICauldronV1(makeAddr("Cauldron2"));
        initalCauldrons[3] = ICauldronV1(makeAddr("Cauldron3"));

        cauldronRegistry.addCauldrons(initalCauldrons);

        for (uint256 i = 0; i < initalCauldrons.length; ++i) {
            ICauldronV1[] memory newCauldronArray = new ICauldronV1[](1);
            newCauldronArray[0] = initalCauldrons[i];

            vm.expectRevert(abi.encodeWithSelector(CauldronRegistry.ErrAlreadyRegistered.selector, initalCauldrons[i]));
            cauldronRegistry.addCauldrons(newCauldronArray);
        }
    }

    function testCannotRegisterZeroAddress() public {
        vm.startPrank(registryOwner);

        ICauldronV1[] memory zeroAddressCauldronArray = new ICauldronV1[](1);
        zeroAddressCauldronArray[0] = ICauldronV1(address(0));

        vm.expectRevert(abi.encodeWithSelector(CauldronRegistry.ErrInvalidCauldron.selector, address(0)));
        cauldronRegistry.addCauldrons(zeroAddressCauldronArray);
    }

    function testTooManyCauldrons() public {
        vm.startPrank(registryOwner);

        ICauldronV1[] memory initalCauldrons = new ICauldronV1[](4);
        initalCauldrons[0] = ICauldronV1(makeAddr("Cauldron0"));
        initalCauldrons[1] = ICauldronV1(makeAddr("Cauldron1"));
        initalCauldrons[2] = ICauldronV1(makeAddr("Cauldron2"));
        initalCauldrons[3] = ICauldronV1(makeAddr("Cauldron3"));

        cauldronRegistry.addCauldrons(initalCauldrons);

        ICauldronV1[] memory moreCauldrons = new ICauldronV1[](5);
        for (uint256 i = 0; i < initalCauldrons.length; ++i) {
            moreCauldrons[i] = initalCauldrons[i];
        }
        moreCauldrons[4] = ICauldronV1(makeAddr("Cauldron4"));
        vm.expectRevert(abi.encodeWithSelector(CauldronRegistry.ErrTooManyCauldrons.selector));
        cauldronRegistry.removeCauldrons(moreCauldrons);
    }

    function testOnlyRemoveRegisteredCauldrons() public {
        vm.startPrank(registryOwner);

        ICauldronV1[] memory unregisteredCauldronArray = new ICauldronV1[](1);
        unregisteredCauldronArray[0] = ICauldronV1(makeAddr("UnregisteredCauldron"));

        vm.expectRevert(abi.encodeWithSelector(CauldronRegistry.ErrEmptyRegistry.selector));
        cauldronRegistry.removeCauldrons(unregisteredCauldronArray);

        ICauldronV1[] memory initalCauldrons = new ICauldronV1[](4);
        initalCauldrons[0] = ICauldronV1(makeAddr("Cauldron0"));
        initalCauldrons[1] = ICauldronV1(makeAddr("Cauldron1"));
        initalCauldrons[2] = ICauldronV1(makeAddr("Cauldron2"));
        initalCauldrons[3] = ICauldronV1(makeAddr("Cauldron3"));

        cauldronRegistry.addCauldrons(initalCauldrons);

        vm.expectRevert(abi.encodeWithSelector(CauldronRegistry.ErrNotRegistered.selector, unregisteredCauldronArray[0]));
        cauldronRegistry.removeCauldrons(unregisteredCauldronArray);
    }

    function testAddRemoveCauldrons() public {
        vm.startPrank(registryOwner);

        ICauldronV1[] memory initalCauldrons = new ICauldronV1[](10);
        initalCauldrons[0] = ICauldronV1(makeAddr("Cauldron0"));
        initalCauldrons[1] = ICauldronV1(makeAddr("Cauldron1"));
        initalCauldrons[2] = ICauldronV1(makeAddr("Cauldron2"));
        initalCauldrons[3] = ICauldronV1(makeAddr("Cauldron3"));
        initalCauldrons[4] = ICauldronV1(makeAddr("Cauldron4"));
        initalCauldrons[5] = ICauldronV1(makeAddr("Cauldron5"));
        initalCauldrons[6] = ICauldronV1(makeAddr("Cauldron6"));
        initalCauldrons[7] = ICauldronV1(makeAddr("Cauldron7"));
        initalCauldrons[8] = ICauldronV1(makeAddr("Cauldron8"));
        initalCauldrons[9] = ICauldronV1(makeAddr("Cauldron9"));

        cauldronRegistry.addCauldrons(initalCauldrons);

        assertEq(cauldronRegistry.cauldronsLength(), 10);
        assertEq(address(cauldronRegistry.cauldrons(0)), address(initalCauldrons[0]));
        assertEq(address(cauldronRegistry.cauldrons(1)), address(initalCauldrons[1]));
        assertEq(address(cauldronRegistry.cauldrons(2)), address(initalCauldrons[2]));
        assertEq(address(cauldronRegistry.cauldrons(3)), address(initalCauldrons[3]));
        assertEq(address(cauldronRegistry.cauldrons(4)), address(initalCauldrons[4]));
        assertEq(address(cauldronRegistry.cauldrons(5)), address(initalCauldrons[5]));
        assertEq(address(cauldronRegistry.cauldrons(6)), address(initalCauldrons[6]));
        assertEq(address(cauldronRegistry.cauldrons(7)), address(initalCauldrons[7]));
        assertEq(address(cauldronRegistry.cauldrons(8)), address(initalCauldrons[8]));
        assertEq(address(cauldronRegistry.cauldrons(9)), address(initalCauldrons[9]));

        ICauldronV1[] memory lastCauldronArray = new ICauldronV1[](1);
        lastCauldronArray[0] = initalCauldrons[initalCauldrons.length - 1];
        cauldronRegistry.removeCauldrons(lastCauldronArray);

        assertEq(cauldronRegistry.cauldronsLength(), 9);
        assertEq(address(cauldronRegistry.cauldrons(0)), address(initalCauldrons[0]));
        assertEq(address(cauldronRegistry.cauldrons(1)), address(initalCauldrons[1]));
        assertEq(address(cauldronRegistry.cauldrons(2)), address(initalCauldrons[2]));
        assertEq(address(cauldronRegistry.cauldrons(3)), address(initalCauldrons[3]));
        assertEq(address(cauldronRegistry.cauldrons(4)), address(initalCauldrons[4]));
        assertEq(address(cauldronRegistry.cauldrons(5)), address(initalCauldrons[5]));
        assertEq(address(cauldronRegistry.cauldrons(6)), address(initalCauldrons[6]));
        assertEq(address(cauldronRegistry.cauldrons(7)), address(initalCauldrons[7]));
        assertEq(address(cauldronRegistry.cauldrons(8)), address(initalCauldrons[8]));

        ICauldronV1[] memory firstCauldronArray = new ICauldronV1[](1);
        firstCauldronArray[0] = initalCauldrons[0];
        cauldronRegistry.removeCauldrons(firstCauldronArray);

        assertEq(cauldronRegistry.cauldronsLength(), 8);
        assertEq(address(cauldronRegistry.cauldrons(0)), address(initalCauldrons[8]));
        assertEq(address(cauldronRegistry.cauldrons(1)), address(initalCauldrons[1]));
        assertEq(address(cauldronRegistry.cauldrons(2)), address(initalCauldrons[2]));
        assertEq(address(cauldronRegistry.cauldrons(3)), address(initalCauldrons[3]));
        assertEq(address(cauldronRegistry.cauldrons(4)), address(initalCauldrons[4]));
        assertEq(address(cauldronRegistry.cauldrons(5)), address(initalCauldrons[5]));
        assertEq(address(cauldronRegistry.cauldrons(6)), address(initalCauldrons[6]));
        assertEq(address(cauldronRegistry.cauldrons(7)), address(initalCauldrons[7]));

        cauldronRegistry.addCauldrons(lastCauldronArray);

        assertEq(cauldronRegistry.cauldronsLength(), 9);
        assertEq(address(cauldronRegistry.cauldrons(0)), address(initalCauldrons[8]));
        assertEq(address(cauldronRegistry.cauldrons(1)), address(initalCauldrons[1]));
        assertEq(address(cauldronRegistry.cauldrons(2)), address(initalCauldrons[2]));
        assertEq(address(cauldronRegistry.cauldrons(3)), address(initalCauldrons[3]));
        assertEq(address(cauldronRegistry.cauldrons(4)), address(initalCauldrons[4]));
        assertEq(address(cauldronRegistry.cauldrons(5)), address(initalCauldrons[5]));
        assertEq(address(cauldronRegistry.cauldrons(6)), address(initalCauldrons[6]));
        assertEq(address(cauldronRegistry.cauldrons(7)), address(initalCauldrons[7]));
        assertEq(address(cauldronRegistry.cauldrons(8)), address(initalCauldrons[9]));

        ICauldronV1[] memory middleCauldrons = new ICauldronV1[](3);
        middleCauldrons[0] = initalCauldrons[3];
        middleCauldrons[1] = initalCauldrons[4];
        middleCauldrons[2] = initalCauldrons[5];
        cauldronRegistry.removeCauldrons(middleCauldrons);

        assertEq(cauldronRegistry.cauldronsLength(), 6);
        assertEq(address(cauldronRegistry.cauldrons(0)), address(initalCauldrons[8]));
        assertEq(address(cauldronRegistry.cauldrons(1)), address(initalCauldrons[1]));
        assertEq(address(cauldronRegistry.cauldrons(2)), address(initalCauldrons[2]));
        assertEq(address(cauldronRegistry.cauldrons(3)), address(initalCauldrons[9]));
        assertEq(address(cauldronRegistry.cauldrons(4)), address(initalCauldrons[7]));
        assertEq(address(cauldronRegistry.cauldrons(5)), address(initalCauldrons[6]));

        uint256 currentCauldronsLength = cauldronRegistry.cauldronsLength();
        ICauldronV1[] memory currentCauldrons = new ICauldronV1[](currentCauldronsLength);
        for (uint256 i = 0; i < currentCauldronsLength; ++i) {
            currentCauldrons[i] = cauldronRegistry.cauldrons(i);
        }
        cauldronRegistry.removeCauldrons(currentCauldrons);

        assertEq(cauldronRegistry.cauldronsLength(), 0);

        cauldronRegistry.addCauldrons(initalCauldrons);

        assertEq(cauldronRegistry.cauldronsLength(), 10);
        assertEq(address(cauldronRegistry.cauldrons(0)), address(initalCauldrons[0]));
        assertEq(address(cauldronRegistry.cauldrons(1)), address(initalCauldrons[1]));
        assertEq(address(cauldronRegistry.cauldrons(2)), address(initalCauldrons[2]));
        assertEq(address(cauldronRegistry.cauldrons(3)), address(initalCauldrons[3]));
        assertEq(address(cauldronRegistry.cauldrons(4)), address(initalCauldrons[4]));
        assertEq(address(cauldronRegistry.cauldrons(5)), address(initalCauldrons[5]));
        assertEq(address(cauldronRegistry.cauldrons(6)), address(initalCauldrons[6]));
        assertEq(address(cauldronRegistry.cauldrons(7)), address(initalCauldrons[7]));
        assertEq(address(cauldronRegistry.cauldrons(8)), address(initalCauldrons[8]));
        assertEq(address(cauldronRegistry.cauldrons(9)), address(initalCauldrons[9]));
    }
}
