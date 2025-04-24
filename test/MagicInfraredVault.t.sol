// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MagicInfraredVault.s.sol";
import {MagicInfraredVault} from "/tokens/MagicInfraredVault.sol";

contract MagicInfraredVaultV2 is MagicInfraredVault {
    address public foo;

    constructor(address __asset) MagicInfraredVault(__asset) {}

    function failingInitialize(address _owner) public reinitializer(1) {
        _initializeOwner(_owner);
    }

    function initializeV2(address _owner, address _foo) public reinitializer(2) {
        _initializeOwner(_owner);
        foo = _foo;
    }
}

contract MagicInfraredVaultTestBase is BaseTest {
    MagicInfraredVault[] vaults;
    ICauldronV4[] cauldrons;

    MagicInfraredVault vault;
    ICauldronV4 cauldron;

    function setUp() public virtual override {
        fork(ChainId.Bera, 4138788);
        super.setUp();

        MagicInfraredVaultScript script = new MagicInfraredVaultScript();
        script.setTesting(true);

        (vaults, cauldrons) = script.deploy();
    }

    function initialize(MagicInfraredVault _vault, ICauldronV4 _cauldron) public {
        vault = _vault;
        cauldron = _cauldron;
    }

    function testStorage() public view {
        assertNotEq(vault.asset(), address(0), "the asset should not be the zero address");
        assertNotEq(vault.owner(), address(0), "the owner should not be the zero address");
    }

    function testUpgrade() public {
        address randomAsset = makeAddr("asset");
        MagicInfraredVaultV2 newImpl = new MagicInfraredVaultV2(randomAsset);

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
        assertEq(MagicInfraredVaultV2(address(vault)).foo(), randomAddr, "foo should be set");
        assertEq(vault.asset(), randomAsset, "asset should be updated");
        popPrank();

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        MagicInfraredVaultV2(address(vault)).initializeV2(alice, alice);
    }

    function testHarvestSimple() public {
        address owner = vault.owner();
        pushPrank(owner);
        vault.harvest(tx.origin);
        popPrank();
    }
}

contract MagicInfrared_WBERA_HONEY_Test is MagicInfraredVaultTestBase {
    function setUp() public virtual override {
        super.setUp();
        initialize(vaults[0], cauldrons[0]);
    }
}

contract MagicInfrared_WETH_WBERA_Test is MagicInfraredVaultTestBase {
    function setUp() public virtual override {
        super.setUp();
        initialize(vaults[1], cauldrons[1]);
    }
}

contract MagicInfrared_WBTC_WBERA_Test is MagicInfraredVaultTestBase {
    function setUp() public virtual override {
        super.setUp();
        initialize(vaults[2], cauldrons[2]);
    }
}
