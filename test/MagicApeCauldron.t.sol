// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MagicApeCauldron.s.sol";

contract MyTest is BaseTest {
    ICauldronV4 cauldron;
    MagicApe magicApe;
    ProxyOracle oracle;

    function setUp() public override {
        forkMainnet(16581143);
        super.setUp();

        MagicApeCauldronScript script = new MagicApeCauldronScript();
        script.setTesting(true);
        (cauldron, magicApe, oracle) = script.run();
    }

    function test() public {
        console2.log(oracle.peekSpot(""));
    }
}
