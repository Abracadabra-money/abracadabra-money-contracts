// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/GmxV2.s.sol";

contract GmxV2Test is BaseTest {
    IGmCauldronOrderAgent orderAgent;
    GmxV2Script.MarketDeployment gmETHDeployment;
    GmxV2Script.MarketDeployment gmBTCDeployment;
    GmxV2Script.MarketDeployment gmARBDeployment;

    function setUp() public override {
        fork(ChainId.Arbitrum, 139531493);
        super.setUp();

        GmxV2Script script = new GmxV2Script();
        script.setTesting(true);

        (orderAgent, gmETHDeployment, gmBTCDeployment, gmARBDeployment) = script.deploy();
    }

    function testEthOracle() public {
        console2.log("=== gmETH OraclePrice ===");
        (, uint256 price) = gmETHDeployment.oracle.peek(bytes(""));
        console2.log("price", price);

        assertEq(price, 1091316200308767747);
    }

    function testBtcOracle() public {
        console2.log("=== gmBTC OraclePrice ===");
        (, uint256 price) = gmBTCDeployment.oracle.peek(bytes(""));
        console2.log("price", price);
    }

    function testArbOracle() public {
        console2.log("=== gmARB OraclePrice ===");
        (, uint256 price) = gmARBDeployment.oracle.peek(bytes(""));
        console2.log("price", price);
        assertEq(price, 1187094061995321781);
    }
}
