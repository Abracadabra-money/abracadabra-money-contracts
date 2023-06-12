// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";

import "script/CrvRefundLens.s.sol";

// import "forge-std/console2.sol";

contract CrvRefundLensTest is BaseTest {
    CrvRefundLens lens;

    function setUp() public override {
        forkMainnet(17332462);
        _setUp();
    }

    function _setUp() public {
        super.setUp();

        CrvRefundLensScript script = new CrvRefundLensScript();
        script.setTesting(true);
        (lens) = script.deploy();
    }

    function testGetRefundInfo() public {
        address cauldronAddress = constants.cauldronAddressMap("mainnet", "CRV", 4);
        address cauldronAddress2 = constants.cauldronAddressMap("mainnet", "CRV2", 4);
        address userAddress = 0x7a16fF8270133F063aAb6C9977183D9e72835428;
        address votingAddress = 0x9B44473E223f8a3c047AD86f387B80402536B029;

        ICauldronV4[] memory cauldrons = new ICauldronV4[](2);
        cauldrons[0] = ICauldronV4(cauldronAddress);
        cauldrons[1] = ICauldronV4(cauldronAddress2);

        CrvRefundLens.RefundInfo memory response = lens.getRefundInfo(cauldrons, userAddress, votingAddress);
        assertEq(response.cauldrons[0], cauldronAddress);
        assertEq(response.cauldrons[1], cauldronAddress2);
        assertEq(response.spellPrice, 573400000000000);
        assertEq(response.userBorrowAmounts[0], 15447680144043364692964558);
        assertEq(response.userBorrowAmounts[1], 4936991292725969487617694);
        assertEq(response.userVeCrvVoted, 9932571841169999548351660);
        assertEq(response.userBribesReceived, 27493831880180501953306);
    }
}
