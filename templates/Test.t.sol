// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/Script.s.sol";

contract MyTest is BaseTest {
    ProxyOracle public oracle;

    function setUp() public override {
        super.setUp();

        forkMainnet(15371985);
        initConfig();

        MyScript script = new MyScript();
        script.setTesting(true);
        (oracle) = script.run();
    }

    function test() public {
        console2.log(oracle.peekSpot(""));
    }
}
