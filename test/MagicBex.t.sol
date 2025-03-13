// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import {MagicBexScript, MagicBexDeployment} from "script/MagicBex.s.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {MagicInfraredVault} from "/tokens/MagicInfraredVault.sol";
import {ICauldronV4} from "/interfaces/ICauldronV4.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";
import {MagicBexVaultHarvester} from "/harvesters/MagicBexVaultHarvester.sol";
import {ExchangeRouterMock} from "test/mocks/ExchangeRouterMock.sol";

address constant WETH_BERA_POOL_WHALE = 0xaF184b4cBc73A9Ca2F51c4a4d80eD67a2578E9F4; // balance: 2404
address constant WBTC_BERA_POOL_WHALE = 0xD7c9f3010eFDFf665EE72580ffA7B4141E56b17E; // balance: 81

contract MagicBexTestBase is BaseTest {
    using SafeTransferLib for address;

    MagicInfraredVault vault;
    ICauldronV4 cauldron;
    ILevSwapperV2 levSwapper;
    ISwapperV2 swapper;
    MagicBexVaultHarvester harvester;
    address bexLpWhale;
    address bexLp;
    address gelato;

    address token0;
    address token1;
    address mim;
    address ibgt;

    function initialize(uint256 chainId, uint256 blockNumber) public returns (MagicBexScript script) {
        fork(chainId, blockNumber);
        super.setUp();

        mim = toolkit.getAddress("mim");
        ibgt = toolkit.getAddress("ibgt");
        script = new MagicBexScript();
        script.setTesting(true);
    }

    function afterDeployed() public {
        gelato = toolkit.getAddress("safe.devOps.gelatoProxy");

        require(address(vault) != address(0), "vault is address(0)");
        require(address(cauldron) != address(0), "cauldron is address(0)");
        require(address(levSwapper) != address(0), "levSwapper is address(0)");
        require(address(swapper) != address(0), "swapper is address(0)");
        require(address(bexLpWhale) != address(0), "bexLpWhale is address(0)");

        bexLp = vault.asset();
        require(address(bexLp) != address(0), "bexLp is address(0)");
        mintMagicVaultTokens();
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
        MagicBexScript script = super.initialize(ChainId.Bera, 2244521);
        MagicBexDeployment memory deployment;
        (deployment, ) = script.deploy();
        vault = deployment.vault;
        cauldron = deployment.cauldron;
        levSwapper = deployment.levSwapper;
        swapper = deployment.swapper;
        harvester = deployment.harvester;
        token0 = toolkit.getAddress("weth");
        token1 = toolkit.getAddress("wbera");

        bexLpWhale = WETH_BERA_POOL_WHALE;

        super.afterDeployed();
    }

    function test_weth_bera_harvest() public {
        advanceTime(7 days);
        ExchangeRouterMock mockExchange = new ExchangeRouterMock(address(0), address(0));
        deal(token0, address(mockExchange), 0.007 ether, true); // ibgt -> 0.007 weth = around $13
        deal(token1, address(mockExchange), 3 ether, true); // wbera -> 3 bera = around $13

        vm.startPrank(harvester.owner());
        harvester.setExchangeRouter(address(mockExchange));
        vm.stopPrank();

        vm.startPrank(gelato);
        bytes[] memory swaps = new bytes[](2);
        swaps[0] = abi.encodeCall(mockExchange.swapArbitraryTokens, (ibgt, token0, address(harvester)));
        swaps[1] = abi.encodeCall(mockExchange.swapArbitraryTokens, (ibgt, token1, address(harvester)));

        uint256[] memory maxAmountsIn = new uint256[](2);
        maxAmountsIn[0] = 0.007 ether;
        maxAmountsIn[1] = 2 ether;

        // harvest 4.35 iBGT @ current block = $30.50
        // assume pool ratio is 50/50
        harvester.run(swaps, maxAmountsIn, 0);

        vm.stopPrank();
    }
}

contract MagicWbtcBeraTest is MagicBexTestBase {
    function setUp() public override {
        MagicBexScript script = super.initialize(ChainId.Bera, 2244521);
        MagicBexDeployment memory deployment;
        (, deployment) = script.deploy();
        vault = deployment.vault;
        cauldron = deployment.cauldron;
        levSwapper = deployment.levSwapper;
        swapper = deployment.swapper;
        harvester = deployment.harvester;
        token0 = toolkit.getAddress("wbtc");
        token1 = toolkit.getAddress("wbera");

        bexLpWhale = WBTC_BERA_POOL_WHALE;

        super.afterDeployed();
    }
}
