// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "utils/BaseTest.sol";

import "script/GlpOracle.s.sol";

contract CauldronV4Test is BaseTest {
    ProxyOracle proxy;

    function setUp() public override {
        forkArbitrum(39141495);
        super.setUp();

        GlpOracleScript script = new GlpOracleScript();
        script.setTesting(true);
        proxy = script.deploy();
    }

    function testValueOnPeekLargerZero() public {
        ( ,uint256 oracleValue) = proxy.peek(abi.encode(proxy));
        console2.log("Oracle Value");
        console.log(1e36 / oracleValue);
        assertGt(oracleValue, 0);
    }
}
