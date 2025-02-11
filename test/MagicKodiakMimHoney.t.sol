// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MagicKodiakMimHoney.s.sol";
import {MagicKodiakVault} from "/tokens/MagicKodiakVault.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";
import {ExchangeRouterMock} from "./mocks/ExchangeRouterMock.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {SwapInfo} from "/swappers/MagicKodiakIslandLevSwapper.sol";

contract MagicKodiakVaultV2 is MagicKodiakVault {
    address public foo;

    constructor(address __asset) MagicKodiakVault(__asset) {}

    function failingInitialize(address _owner) public reinitializer(1) {
        _initializeOwner(_owner);
    }

    function initializeV2(address _owner, address _foo) public reinitializer(2) {
        _initializeOwner(_owner);
        foo = _foo;
    }
}

contract MagicKodiakMimHoneyTest is BaseTest {
    MagicKodiakVault vault;
    IKodiakVaultV1 kodiakVault;
    ICauldronV4 cauldron;
    ISwapperV2 swapper;
    ILevSwapperV2 levSwapper;
    address token0;
    address token1;
    address mim;
    IBentoBoxLite box;

    function setUp() public override {
        fork(ChainId.Bera, 790881);
        super.setUp();

        MagicKodiakMimHoneyScript script = new MagicKodiakMimHoneyScript();
        script.setTesting(true);

        (vault, cauldron, swapper, levSwapper) = script.deploy();

        kodiakVault = IKodiakVaultV1(vault.asset());
        token0 = kodiakVault.token0();
        token1 = kodiakVault.token1();
        mim = toolkit.getAddress("mim");
        box = IBentoBoxLite(toolkit.getAddress("degenBox"));
    }

    function testStorage() public view {
        assertEq(vault.asset(), toolkit.getAddress("kodiak.mimhoney"), "the asset should be Kodiak MIM-HONEY island tokens");
        assertNotEq(vault.owner(), address(0), "the owner should not be the zero address");
    }

    function testUpgrade() public {
        address randomAsset = makeAddr("asset");
        MagicKodiakVaultV2 newImpl = new MagicKodiakVaultV2(randomAsset);

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        vault.initialize(alice);

        pushPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        vault.upgradeToAndCall(address(newImpl), "");
        popPrank();

        address owner = vault.owner();
        pushPrank(owner);
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        vault.upgradeToAndCall(address(newImpl), abi.encodeCall(newImpl.failingInitialize, (owner)));

        address randomAddr = makeAddr("addr");

        vault.upgradeToAndCall(address(newImpl), abi.encodeCall(newImpl.initializeV2, (owner, randomAddr)));
        assertEq(vault.owner(), owner, "owner should be the same");
        assertEq(MagicKodiakVaultV2(address(vault)).foo(), randomAddr, "foo should be set");
        assertEq(vault.asset(), randomAsset, "asset should be updated");
        popPrank();

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        MagicKodiakVaultV2(address(vault)).initializeV2(alice, alice);
    }

    function testHarvestSimple() public {
        address owner = vault.owner();
        pushPrank(owner);
        vault.harvest(tx.origin);
        popPrank();
    }

    function testSwappers() public {
        uint256 shareFrom;

        // Leverage
        {
            ExchangeRouterMock routerMock = new ExchangeRouterMock(mim, token1);

            deal(mim, address(box), 1000 ether);
            box.deposit(mim, address(box), address(levSwapper), 1000 ether, 0);
            deal(token1, address(routerMock), 500 ether);

            uint256 balanceBefore = box.balanceOf(address(vault), address(swapper));
            bytes memory data = abi.encode(
                SwapInfo({to: address(0), swapData: ""}), // token0 is MIM, remaining will be 500 MIMs
                SwapInfo({to: address(routerMock), swapData: abi.encodeCall(routerMock.swapExactIn, (500 ether, address(levSwapper)))})
            );

            levSwapper.swap(address(swapper), 0, 1000 ether, data);

            shareFrom = box.balanceOf(address(vault), address(swapper));
            assertGt(shareFrom, balanceBefore, "balance should be greater");
        }

        // Deleverage
        {
            ExchangeRouterMock routerMock = new ExchangeRouterMock(token1, mim);
            deal(mim, address(routerMock), 500 ether);

            bytes memory data = abi.encode(
                SwapInfo({to: address(0), swapData: ""}), // token0 is MIM, remaining will be 500 MIMs
                SwapInfo({to: address(routerMock), swapData: abi.encodeCall(routerMock.swapExactIn, (499999999999999999999, address(swapper)))})
            );

            uint256 balanceBefore = box.balanceOf(address(mim), bob);
            swapper.swap(address(0), address(0), bob, 0, shareFrom, data);
            uint256 balanceAfter = box.balanceOf(address(mim), bob);
            assertGt(balanceAfter, balanceBefore, "balance should be greater");
        }
    }
}
