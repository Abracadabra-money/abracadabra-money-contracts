// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";

import "script/CrvRefundLens.s.sol";

// import "forge-std/console2.sol";

contract CrvRefundLensTest is BaseTest {
    CrvRefundLens lens;
    address constant OPS_MULTISIG = 0xDF2C270f610Dc35d8fFDA5B453E74db5471E126B;
    address constant DEGENBOX = 0xd96f48665a1410C0cd669A88898ecA36B9Fc2cce;

    function setUp() public override {
        forkMainnet(17282745);
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
        assertEq(response.spellPrice, 599950000000000);
        assertEq(response.userBorrowAmounts[0], 15415295577108789880371082);
        assertEq(response.userBorrowAmounts[1], 4926641363901696258347794);
        assertEq(response.userVeCrvVoted, 9981023415425604566245084);
        assertEq(response.userBribesReceived, 25832844436203938926120);
    }

    function testHandleFees() public {
        pushPrank(OPS_MULTISIG);
        address cauldronAddress = constants.cauldronAddressMap("mainnet", "CRV", 4);
        // address cauldronAddress2 = constants.cauldronAddressMap("mainnet", "CRV2", 4);

        ICauldronV4[] memory cauldrons = new ICauldronV4[](1);
        cauldrons[0] = ICauldronV4(cauldronAddress);
        // cauldrons[1] = ICauldronV4(cauldronAddress2);

        uint256 totalFeesWithdrawn = lens.handleFees(cauldrons, 0);
        // assertEq(totalFeesWithdrawn, 0);
    }
}
