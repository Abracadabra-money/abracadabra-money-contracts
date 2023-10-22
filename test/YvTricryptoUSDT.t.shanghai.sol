// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/YvTricryptoUSDT.s.shanghai.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {ERC20, IERC20} from "BoringSolidity/ERC20.sol";
import {ExchangeRouterMock} from "./mocks/ExchangeRouterMock.sol";

contract YvTricryptoUSDTTest is BaseTest {
    using SafeTransferLib for address;
    ISwapperV2 swapper;
    ILevSwapperV2 levSwapper;

    address vault;
    address mim;
    address box;
    address usdt;
    ExchangeRouterMock exchange;

    address constant VAULT_WHALE = 0x99b95c60B2d68DB15dfFB11A71076A31ccaF1487;
    address constant MIM_WHALE = 0xF02e86D9E0eFd57aD034FaF52201B79917fE0713;

    function setUp() public override {
        fork(ChainId.Mainnet, 18403004);
        super.setUp();

        YvTricryptoUSDTScript script = new YvTricryptoUSDTScript();
        script.setTesting(true);

        mim = toolkit.getAddress(block.chainid, "mim");
        usdt = toolkit.getAddress(block.chainid, "usdt");
        vault = toolkit.getAddress(block.chainid, "yearn.yvTricryptoUSDT");
        box = toolkit.getAddress(block.chainid, "degenBox");

        (swapper, levSwapper) = script.deploy();

        exchange = ExchangeRouterMock(toolkit.getAddress(block.chainid, "aggregators.zeroXExchangeProxy"));
        vm.etch(address(exchange), address(new ExchangeRouterMock(ERC20(address(0)), ERC20(address(0)))).code);
    }

    function testSwapper() public {
        exchange.setTokens(ERC20(usdt), ERC20(mim));
        deal(mim, address(exchange), 1_000_000 ether);

        pushPrank(VAULT_WHALE);
        vault.safeTransfer(box, 400 ether);
        (, uint256 shareOut) = IBentoBoxV1(box).deposit(IERC20(vault), box, address(swapper), 400 ether, 0);
        swapper.swap(address(0), address(0), address(swapper), 0, shareOut, abi.encode(0, "0xaaaaaaaa"));
        popPrank();

        assertEq(IBentoBoxV1(box).balanceOf(IERC20(mim), address(swapper)), 1_000_000 ether);
    }

    function testLevSwapper() public {
        exchange.setTokens(ERC20(mim), ERC20(usdt));
        deal(usdt, address(exchange), 1_000_000e6);

        pushPrank(MIM_WHALE);
        mim.safeTransfer(box, 1_000_000 ether);
        (, uint256 shareOut) = IBentoBoxV1(box).deposit(IERC20(mim), box, address(levSwapper), 1_000_000 ether, 0);
        levSwapper.swap(address(levSwapper), 0, shareOut, abi.encode(usdt, 0, "0xaaaaaaaa"));
        popPrank();

        assertEq(IBentoBoxV1(box).balanceOf(IERC20(vault), address(levSwapper)), 864565056829961097781);
    }
}
