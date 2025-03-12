// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import {MagicBexScript, MagicBexDeployment} from "script/MagicBex.s.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {MagicInfraredVault} from "/tokens/MagicInfraredVault.sol";
import {ICauldronV4} from "/interfaces/ICauldronV4.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";

address constant WETH_BERA_POOL_WHALE = 0xaF184b4cBc73A9Ca2F51c4a4d80eD67a2578E9F4; // balance: 2404
address constant WBTC_BERA_POOL_WHALE = 0xD7c9f3010eFDFf665EE72580ffA7B4141E56b17E; // balance: 81

contract MagicBexTestBase is BaseTest {
    using SafeTransferLib for address;

    MagicInfraredVault vault;
    ICauldronV4 cauldron;
    ILevSwapperV2 levSwapper;
    ISwapperV2 swapper;
    address bexLpWhale;
    address bexLp;

    function initialize(uint256 chainId, uint256 blockNumber, address _bexLpWhale) public returns (MagicBexScript script) {
        fork(chainId, blockNumber);
        super.setUp();

        bexLpWhale = _bexLpWhale;
        script = new MagicBexScript();
        script.setTesting(true);
    }

    function afterDeployed() public {
        require(address(vault) != address(0), "vault is address(0)");
        require(address(cauldron) != address(0), "cauldron is address(0)");
        require(address(levSwapper) != address(0), "levSwapper is address(0)");
        require(address(swapper) != address(0), "swapper is address(0)");
        require(address(bexLpWhale) != address(0), "bexLpWhale is address(0)");

        bexLp = vault.asset();
        require(address(bexLp) != address(0), "bexLp is address(0)");
        mintMagicVaultTokens();
    }

    function testHarvest() public {
        vm.startPrank(address(vault));
        //vault.harvest();
        vm.stopPrank();
    }

    function mintMagicVaultTokens() public {
        uint256 lpBalance = address(bexLp).balanceOf(bexLpWhale);
        require(lpBalance > 0, string.concat(vm.toString(bexLp), " lp balance is 0, bexLpWhale: ", vm.toString(bexLpWhale)));

        vm.startPrank(bexLpWhale);
        bexLp.safeApprove(address(vault), lpBalance);
        vault.deposit(lpBalance, alice);
        vm.stopPrank();
    }
}

contract MagicWethBeraTest is MagicBexTestBase {
    function setUp() public override {
        MagicBexScript script = super.initialize(ChainId.Bera, 2244521, WETH_BERA_POOL_WHALE);
        MagicBexDeployment memory deployment;
        (deployment, ) = script.deploy();
        vault = deployment.vault;
        cauldron = deployment.cauldron;
        levSwapper = deployment.levSwapper;
        swapper = deployment.swapper;
        super.afterDeployed();
    }
}

contract MagicWbtcBeraTest is MagicBexTestBase {
    function setUp() public override {
        MagicBexScript script = super.initialize(ChainId.Bera, 2244521, WBTC_BERA_POOL_WHALE);
        MagicBexDeployment memory deployment;
        (, deployment) = script.deploy();
        vault = deployment.vault;
        cauldron = deployment.cauldron;
        levSwapper = deployment.levSwapper;
        swapper = deployment.swapper;
        super.afterDeployed();
    }
}
