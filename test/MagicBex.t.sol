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
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";

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
    IBentoBoxLite box;

    address token0;
    address token1;
    address mim;
    address ibgt;

    function initialize(uint256 chainId, uint256 blockNumber) public returns (MagicBexScript script) {
        fork(chainId, blockNumber);
        super.setUp();

        mim = toolkit.getAddress("mim");
        ibgt = toolkit.getAddress("ibgt");
        box = IBentoBoxLite(toolkit.getAddress("degenBox"));

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
    using SafeTransferLib for address;

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

        // harvest and ensure share price increased
        uint256 initialSharePrice = vault.convertToAssets(1 ether);
        harvester.run(swaps, maxAmountsIn, 0);
        assertGt(vault.convertToAssets(1 ether), initialSharePrice);

        vm.stopPrank();
    }

    function test_weth_bera_swapper() public {
        // Setup mock exchange with some tokens
        ExchangeRouterMock mockExchange = new ExchangeRouterMock(address(0), address(0));

        // Setup harvester to use mock exchange
        vm.startPrank(harvester.owner());
        harvester.setExchangeRouter(address(mockExchange));
        vm.stopPrank();

        // Mint some vault tokens to BentoBox and deposit shares to swapper
        uint256 vaultAmount = 1 ether;
        deal(address(vault), address(alice), vaultAmount, true);
        pushPrank(alice);
        address(vault).safeTransfer(address(box), vaultAmount);
        popPrank();

        (, uint256 shareFrom) = box.deposit(address(vault), address(box), address(swapper), vaultAmount, 0);

        // Prepare swap data
        address[] memory to = new address[](2);
        to[0] = address(mockExchange);
        to[1] = address(mockExchange);

        bytes[] memory swaps = new bytes[](2);
        swaps[0] = abi.encodeCall(mockExchange.swapArbitraryTokensExactAmountOut, (token0, mim, 50 ether, address(swapper)));
        swaps[1] = abi.encodeCall(mockExchange.swapArbitraryTokensExactAmountOut, (token1, mim, 50 ether, address(swapper)));

        bytes memory swapData = abi.encode(to, swaps);

        deal(mim, address(mockExchange), 100 ether, true);

        // Execute swap through cauldron
        vm.startPrank(address(cauldron));
        swapper.swap(address(0), address(0), alice, 0, shareFrom, swapData);
        vm.stopPrank();

        // Verify alice received MIM in BentoBox
        assertGt(box.balanceOf(mim, alice), 0);
    }

    function test_weth_bera_lev_swapper() public {
        // Setup mock exchange with some tokens
        ExchangeRouterMock mockExchange = new ExchangeRouterMock(address(0), address(0));
        deal(token0, address(mockExchange), 0.007 ether, true);
        deal(token1, address(mockExchange), 3 ether, true);

        // Setup harvester to use mock exchange
        vm.startPrank(harvester.owner());
        harvester.setExchangeRouter(address(mockExchange));
        vm.stopPrank();

        // Mint some MIM to BentoBox and deposit shares to levSwapper
        uint256 mimAmount = 100 ether;
        deal(mim, address(alice), mimAmount, true);
        pushPrank(alice);
        mim.safeTransfer(address(box), mimAmount);
        popPrank();

        (, uint256 shareFrom) = box.deposit(mim, address(box), address(levSwapper), mimAmount, 0);

        // Prepare swap data
        address[] memory to = new address[](2);
        to[0] = address(mockExchange);
        to[1] = address(mockExchange);

        bytes[] memory swaps = new bytes[](2);
        swaps[0] = abi.encodeCall(mockExchange.swapArbitraryTokens, (mim, token0, address(levSwapper)));
        swaps[1] = abi.encodeCall(mockExchange.swapArbitraryTokens, (mim, token1, address(levSwapper)));

        bytes memory swapData = abi.encode(to, swaps);

        // Execute swap through cauldron
        vm.startPrank(address(cauldron));
        levSwapper.swap(alice, 0, shareFrom, swapData);
        vm.stopPrank();

        // Verify alice received LP tokens in BentoBox
        assertGt(box.balanceOf(address(vault), alice), 0);
    }
}

contract MagicWbtcBeraTest is MagicBexTestBase {
    using SafeTransferLib for address;

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

    function test_wbtc_bera_harvest() public {
        advanceTime(7 days);
        ExchangeRouterMock mockExchange = new ExchangeRouterMock(address(0), address(0));
        deal(token0, address(mockExchange), 0.00015 * 10 ** 8, true); // ibgt -> 0.00015 wbtc = around $13
        deal(token1, address(mockExchange), 3 ether, true); // wbera -> 3 bera = around $13

        vm.startPrank(harvester.owner());
        harvester.setExchangeRouter(address(mockExchange));
        vm.stopPrank();

        vm.startPrank(gelato);
        bytes[] memory swaps = new bytes[](2);
        swaps[0] = abi.encodeCall(mockExchange.swapArbitraryTokens, (ibgt, token0, address(harvester)));
        swaps[1] = abi.encodeCall(mockExchange.swapArbitraryTokens, (ibgt, token1, address(harvester)));

        uint256[] memory maxAmountsIn = new uint256[](2);
        maxAmountsIn[0] = 0.00015 * 10 ** 8;
        maxAmountsIn[1] = 2 ether;

        // harvest and ensure share price increased
        uint256 initialSharePrice = vault.convertToAssets(1 ether);
        harvester.run(swaps, maxAmountsIn, 0);
        assertGt(vault.convertToAssets(1 ether), initialSharePrice);

        vm.stopPrank();
    }

    function test_wbtc_bera_swapper() public {
        // Setup mock exchange with some tokens
        ExchangeRouterMock mockExchange = new ExchangeRouterMock(address(0), address(0));

        // Setup harvester to use mock exchange
        vm.startPrank(harvester.owner());
        harvester.setExchangeRouter(address(mockExchange));
        vm.stopPrank();

        // Mint some vault tokens to BentoBox and deposit shares to swapper
        uint256 vaultAmount = 1 ether;
        deal(address(vault), address(alice), vaultAmount, true);
        pushPrank(alice);
        address(vault).safeTransfer(address(box), vaultAmount);
        popPrank();

        (, uint256 shareFrom) = box.deposit(address(vault), address(box), address(swapper), vaultAmount, 0);

        // Prepare swap data
        address[] memory to = new address[](2);
        to[0] = address(mockExchange);
        to[1] = address(mockExchange);

        bytes[] memory swaps = new bytes[](2);
        swaps[0] = abi.encodeCall(mockExchange.swapArbitraryTokensExactAmountOut, (token0, mim, 50 ether, address(swapper)));
        swaps[1] = abi.encodeCall(mockExchange.swapArbitraryTokensExactAmountOut, (token1, mim, 50 ether, address(swapper)));

        bytes memory swapData = abi.encode(to, swaps);

        deal(mim, address(mockExchange), 100 ether, true);

        // Execute swap through cauldron
        vm.startPrank(address(cauldron));
        swapper.swap(address(0), address(0), alice, 0, shareFrom, swapData);
        vm.stopPrank();

        // Verify alice received MIM in BentoBox
        assertGt(box.balanceOf(mim, alice), 0);
    }

    function test_wbtc_bera_lev_swapper() public {
        // Setup mock exchange with some tokens
        ExchangeRouterMock mockExchange = new ExchangeRouterMock(address(0), address(0));
        deal(token0, address(mockExchange), 0.007 ether, true);
        deal(token1, address(mockExchange), 3 ether, true);

        // Setup harvester to use mock exchange
        vm.startPrank(harvester.owner());
        harvester.setExchangeRouter(address(mockExchange));
        vm.stopPrank();

        // Mint some MIM to BentoBox and deposit shares to levSwapper
        uint256 mimAmount = 100 ether;
        deal(mim, address(alice), mimAmount, true);
        pushPrank(alice);
        mim.safeTransfer(address(box), mimAmount);
        popPrank();

        (, uint256 shareFrom) = box.deposit(mim, address(box), address(levSwapper), mimAmount, 0);

        // Prepare swap data
        address[] memory to = new address[](2);
        to[0] = address(mockExchange);
        to[1] = address(mockExchange);

        bytes[] memory swaps = new bytes[](2);
        swaps[0] = abi.encodeCall(mockExchange.swapArbitraryTokens, (mim, token0, address(levSwapper)));
        swaps[1] = abi.encodeCall(mockExchange.swapArbitraryTokens, (mim, token1, address(levSwapper)));

        bytes memory swapData = abi.encode(to, swaps);

        // Execute swap through cauldron
        vm.startPrank(address(cauldron));
        levSwapper.swap(alice, 0, shareFrom, swapData);
        vm.stopPrank();

        // Verify alice received LP tokens in BentoBox
        assertGt(box.balanceOf(address(vault), alice), 0);
    }
}
