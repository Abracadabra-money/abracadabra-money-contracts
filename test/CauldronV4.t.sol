// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IOracle.sol";
import "cauldrons/CauldronV4.sol";
import "utils/CauldronLib.sol";
import "script/CauldronV4.s.sol";

contract CauldronV4Test is BaseTest {
    uint8 internal constant ACTION_CALL = 30;
    IBentoBoxV1 public degenBox;
    ICauldronV4 public cauldron;
    CauldronV4 public masterContract;
    IERC20 public mim;
    IERC20 public weth;

    function setUp() public override {
        forkMainnet(15493294);
        super.setUp();

        CauldronV4Script script = new CauldronV4Script();
        script.setTesting(true);
        masterContract = script.run();

        degenBox = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
        mim = IERC20(constants.getAddress("mainnet.mim"));
        weth = IERC20(constants.getAddress("mainnet.weth"));

        vm.startPrank(degenBox.owner());
        degenBox.whitelistMasterContract(address(masterContract), true);
        cauldron = CauldronLib.deployCauldronV4(
            degenBox,
            address(masterContract),
            weth,
            IOracle(0x6C86AdB5696d2632973109a337a50EF7bdc48fF1),
            "",
            7000, // 70% ltv
            200, // 2% interests
            200, // 2% opening
            800 // 8% liquidation
        );

        vm.stopPrank();
    }

    function testDefaultBlacklistedCallees() public {
        bytes memory callData = abi.encode(
            IBentoBoxV1.balanceOf.selector,
            constants.getAddress("mainnet.mim"),
            0xfB3485c2e209A5cfBDC1447674256578f1A80eE3
        );
        uint8[] memory actions = new uint8[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory datas = new bytes[](1);

        actions[0] = ACTION_CALL;
        values[0] = 0;
        datas[0] = abi.encode(address(degenBox), callData, false, false, uint8(0));

        vm.expectRevert("Cauldron: can't call");
        cauldron.cook(actions, values, datas);

        datas[0] = abi.encode(address(cauldron), callData, false, false, uint8(0));
        vm.expectRevert("Cauldron: can't call");
        cauldron.cook(actions, values, datas);
    }

    function testCannotChangeDegenBoxAndCauldronBlacklisting() public {
        vm.startPrank(masterContract.owner());
        vm.expectRevert("invalid callee");
        cauldron.setBlacklistedCallee(address(degenBox), false);
        vm.expectRevert("invalid callee");
        cauldron.setBlacklistedCallee(address(cauldron), false);
    }

    function testCustomBlacklistedCallee() public {
        // some random proxy oracle
        address callee = 0x6C86AdB5696d2632973109a337a50EF7bdc48fF1;

        bytes memory callData = abi.encode(IOracle.peekSpot.selector, "");
        uint8[] memory actions = new uint8[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory datas = new bytes[](1);

        actions[0] = ACTION_CALL;
        values[0] = 0;
        datas[0] = abi.encode(callee, callData, false, false, uint8(0));

        cauldron.cook(actions, values, datas);

        vm.prank(masterContract.owner());
        cauldron.setBlacklistedCallee(callee, true);

        vm.expectRevert("Cauldron: can't call");
        cauldron.cook(actions, values, datas);

        vm.prank(masterContract.owner());
        cauldron.setBlacklistedCallee(callee, false);
        cauldron.cook(actions, values, datas);
    }
}
