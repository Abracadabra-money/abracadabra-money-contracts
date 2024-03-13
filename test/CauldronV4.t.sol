// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/ERC20.sol";
import "BoringSolidity/libraries/BoringRebase.sol";
import "utils/BaseTest.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IOracle.sol";
import "interfaces/IWETH.sol";
import "cauldrons/CauldronV4.sol";
import "utils/CauldronDeployLib.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {FixedPriceOracle} from "oracles/FixedPriceOracle.sol";

contract CauldronV4Test is BaseTest {
    using RebaseLibrary for Rebase;
    event LogStrategyQueued(IERC20 indexed token, IStrategy indexed strategy);

    uint8 internal constant ACTION_CALL = 30;
    IBentoBoxV1 public degenBox;
    ICauldronV4 public cauldron;
    CauldronV4 public masterContract;
    ERC20 public mim;
    ERC20 public weth;

    function setUp() public override {
        _setup();
    }

    function _setup() private {
        fork(ChainId.Mainnet, 15998564);
        super.setUp();

        degenBox = IBentoBoxV1(toolkit.getAddress("mainnet.degenBox"));
        masterContract = new CauldronV4(degenBox, IERC20(toolkit.getAddress("mainnet.mim")));
        degenBox = IBentoBoxV1(toolkit.getAddress("mainnet.degenBox"));
        mim = ERC20(toolkit.getAddress("mainnet.mim"));
        weth = ERC20(toolkit.getAddress("mainnet.weth"));

        vm.startPrank(degenBox.owner());
        degenBox.whitelistMasterContract(address(masterContract), true);

        bytes memory data = CauldronDeployLib.getCauldronParameters(
            weth,
            IOracle(0x6C86AdB5696d2632973109a337a50EF7bdc48fF1),
            "",
            7000,
            200,
            200,
            800
        );
        cauldron = ICauldronV4(IBentoBoxV1(degenBox).deploy(address(masterContract), data, true));

        vm.stopPrank();

        address mimWhale = 0xbbc4A8d076F4B1888fec42581B6fc58d242CF2D5;
        vm.startPrank(mimWhale);
        mim.approve(address(degenBox), type(uint256).max);
        degenBox.deposit(mim, mimWhale, address(cauldron), 10_000_000 ether, 0);
        vm.stopPrank();
    }

    function testDefaultBlacklistedCallees() public {
        _setup();
        bytes memory callData = abi.encode(
            IBentoBoxV1.balanceOf.selector,
            toolkit.getAddress("mainnet.mim"),
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

        datas[0] = abi.encode(address(degenBox.owner()), callData, false, false, uint8(0));
        vm.expectRevert("Cauldron: can't call");
        cauldron.cook(actions, values, datas);
    }

    function testCannotChangeDegenBoxAndCauldronBlacklisting() public {
        _setup();
        vm.startPrank(masterContract.owner());
        vm.expectRevert("invalid callee");
        cauldron.setBlacklistedCallee(address(degenBox), false);
        vm.expectRevert("invalid callee");
        cauldron.setBlacklistedCallee(address(cauldron), false);
    }

    function testCustomBlacklistedCallee() public {
        _setup();
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
    
    function testInitMasterContract() public {
        CauldronV4 mc = new CauldronV4(degenBox, mim);

        vm.expectRevert(abi.encodeWithSignature("ErrNotClone()"));
        mc.init("");

        FixedPriceOracle oracle = new FixedPriceOracle("",0,0);
        address _cauldron = LibClone.clone(address(mc));
        ICauldronV4(_cauldron).init(abi.encode(0x1, oracle, "", 7000, 200, 200, 800));
    }
}
