// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import {SDEUSDSwapperScript} from "script/SDEUSDSwapper.s.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ExchangeRouterMock} from "./mocks/ExchangeRouterMock.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";

contract SDEUSDSwapperTest is BaseTest {
    using SafeTransferLib for address;

    address box;
    address sdeusd;
    address deusd;
    address mim;

    ISwapperV2 swapper;

    address constant SDEUSD_WHALE = 0xB0148a65D3f0597bC831c1D3CB5C48068c064Ca3;

    function setUp() public override {
        fork(ChainId.Mainnet, 20571282);
        super.setUp();

        SDEUSDSwapperScript script = new SDEUSDSwapperScript();
        script.setTesting(true);

        swapper = script.deploy();

        box = toolkit.getAddress("degenBox");
        sdeusd = toolkit.getAddress("elixir.sdeusd");
        deusd = toolkit.getAddress("elixir.deusd");
        mim = toolkit.getAddress("mim");
    }

    function test() public {
        pushPrank(SDEUSD_WHALE);
        sdeusd.safeTransfer(box, 1000 ether);
        popPrank();
        (, uint share) = IBentoBoxLite(box).deposit(sdeusd, box, address(swapper), 1000 ether, 0);

        ExchangeRouterMock mockExchange = new ExchangeRouterMock(deusd, mim);

        deal(mim, address(mockExchange), 1000 ether, true);

        swapper.swap(
            address(0),
            address(0),
            alice,
            999 ether,
            share,
            abi.encode(address(mockExchange), abi.encodeCall(mockExchange.swap, address(swapper)))
        );
    }
}
