// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/Berachain.s.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract BerachainTest is BaseTest {
    using SafeTransferLib for address;

    ISwapperV2 swapper;
    ILevSwapperV2 levSwapper;

    address lp;

    function setUp() public override {
        fork(ChainId.Bera, 56035);
        super.setUp();

        BerachainScript script = new BerachainScript();
        script.setTesting(true);

        (swapper, levSwapper) = script.deploy();

        lp = toolkit.getAddress(block.chainid, "bex.token.mimhoney");
    }

    function test() public {
        
    }
}
