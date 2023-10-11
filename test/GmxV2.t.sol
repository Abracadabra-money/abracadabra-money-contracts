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
        fork(ChainId.Arbitrum, 139685420);
        super.setUp();

        GmxV2Script script = new GmxV2Script();
        script.setTesting(true);

        (orderAgent, gmETHDeployment, gmBTCDeployment, gmARBDeployment) = script.deploy();
    }

    function testOracles() public {
        uint256 price;

        console2.log("=== gmETH OraclePrice ===");
        (, price) = gmETHDeployment.oracle.peek(bytes(""));
        console2.log("price", price);
        assertEq(price, 1089611872333813650);

        console2.log("=== gmBTC OraclePrice ===");
        (, price) = gmBTCDeployment.oracle.peek(bytes(""));
        console2.log("price", price);
        assertEq(price, 1008339991773323838);

        console2.log("=== gmARB OraclePrice ===");
        (, price) = gmARBDeployment.oracle.peek(bytes(""));
        console2.log("price", price);
        assertEq(price, 1189214556682150869);
    }
}
