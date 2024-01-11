// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/Berachain.s.sol";

contract BerachainTest is BaseTest {
    ISwapperV2 swapper;
    ILevSwapperV2 levSwapper;

    function setUp() public override {
        fork(ChainId.Bera, 48400);
        super.setUp();

        BerachainScript script = new BerachainScript();
        script.setTesting(true);

        (swapper, levSwapper) = script.deploy();
    }

    function test() public {

    }
}
