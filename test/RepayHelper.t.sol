// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/RepayHelper.s.sol";

contract RepayHelperTest is BaseTest {
    RepayHelper public helper;

    event LogBorrow(address indexed from, address indexed to, uint256 amount, uint256 part);
    event LogRepay(address indexed from, address indexed to, uint256 amount, uint256 part);

    function setUp() public override {
        fork(ChainId.Mainnet, 15371985);
        super.setUp();

        RepayHelperScript script = new RepayHelperScript();
        script.setTesting(true);
        (helper) = script.deploy();
        vm.startPrank(helper.safe());
        helper.magicInternetMoney().approve(address(helper), 10 * 1e6 * 1e18);
        vm.stopPrank();
        vm.startPrank(helper.multisig());
        helper.magicInternetMoney().approve(address(helper), 10 * 1e6 * 1e18);
        vm.stopPrank();
    }

    function testRepayTotal() public {
        ICauldronV4 cauldron = ICauldronV4(0xFFbF4892822e0d552CFF317F65e1eE7b5D3d9aE6);
        vm.startPrank(helper.safe());
        helper.repayTotal(getAddressArray(), cauldron);
        vm.stopPrank();
        assertEq(cauldron.userBorrowPart(getAddressArray()[0]), 0);
    }

    function testRepayTotalMultisig() public {
        ICauldronV4 cauldron = ICauldronV4(0xFFbF4892822e0d552CFF317F65e1eE7b5D3d9aE6);
        vm.startPrank(helper.multisig());
        helper.repayTotalMultisig(getAddressArray(), cauldron);
        vm.stopPrank();
        assertEq(cauldron.userBorrowPart(getAddressArray()[0]), 0);
    }

    function testNotRepayTotal() public {
        ICauldronV4 cauldron = ICauldronV4(0xFFbF4892822e0d552CFF317F65e1eE7b5D3d9aE6);
        vm.expectRevert();
        helper.repayTotalMultisig(getAddressArray(), cauldron);
    }

    function testNotRepayTotalMultisig() public {
        ICauldronV4 cauldron = ICauldronV4(0xFFbF4892822e0d552CFF317F65e1eE7b5D3d9aE6);
        vm.expectRevert();
        helper.repayTotalMultisig(getAddressArray(), cauldron);
    }

    function getAddressArray() public pure returns (address[] memory) {
        address[10] memory addresses = [
            0xC877D91a16a5fb483dD96a4a00Ede9B240374a25,
            0x7dA08FBa7A69c67c0D06fD433aF0C53F9c75CeE8,
            0x73e60cD967E957bC6e074F93320FfA1d52697D5b,
            0x28eAd95628610B4eE91408cFE1C225c71AB6e7A8,
            0xAB12253171A0d73df64B115cD43Fe0A32Feb9dAA,
            0x50Ad452DD4434E547c88262a00f08517743B4c02,
            0x0ef6E547DD86de09F0E8eCE1E5A9f5cCB335aDE1,
            0x7Cfed2A2d4a98680daC6aA55120f5AF2EC562EbD,
            0x3F7C10cBbb1EA1046a80B738b9Eaf3217410c7F6,
            0xEa8CDB581e5F46491F03e25fe36b095df5Bc1117
        ];
        address[] memory dynamicArray = new address[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            dynamicArray[i] = addresses[i];
        }
        return dynamicArray;
    }


}
