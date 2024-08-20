// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MagicKodiak.s.sol";
import {MagicKodiakVault} from "/tokens/MagicKodiakVault.sol";

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

contract MagicKodiakTest is BaseTest {
    MagicKodiakVault vault;

    function setUp() public override {
        fork(ChainId.Bera, 2856031);
        super.setUp();

        MagicKodiakScript script = new MagicKodiakScript();
        script.setTesting(true);

        vault = script.deploy();
    }

    function testStorage() public view {
        assertEq(vault.asset(), toolkit.getAddress("kodiak.islands.mimhoney"), "the asset should be the MIM-HONEY island tokens");
        assertNotEq(vault.owner(), address(0), "the owner should not be the zero address");
    }

    function testUpgrade() public {
        address randomAsset = makeAddr("asset");
        MagicKodiakVaultV2 newImpl = new MagicKodiakVaultV2(randomAsset);

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        vault.initialize(alice, address(0));

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
}
