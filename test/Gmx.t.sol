// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/Gmx.s.sol";

abstract contract BaseGmxTest is BaseTest {
    ProxyOracle public oracle;

    function setUp() public virtual override {
        super.setUp();
        GmxScript script = new GmxScript();
        script.setTesting(true);
        (oracle) = script.run();
    }

    function test() public {
        console2.log("from test");
    }
}

contract ArbitrumGmxTest is BaseGmxTest {
    function setUp() public override {
        forkArbitrum(26465949);
        super.setUp();
    }
}
