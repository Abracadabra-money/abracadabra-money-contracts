// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/libraries/BoringERC20.sol";
import "utils/BaseTest.sol";
import "script/GmOracleWithAggregator.s.sol";

contract GmxLensTest is BaseTest {
    using BoringERC20 for IERC20;
    GmOracleWithAggregator oracle;
    function setUp() public override {}

    function testPrice() public {
        fork(ChainId.Arbitrum, 138079074);
        super.setUp();

        GmOracleWithAggregatorScript script = new GmOracleWithAggregatorScript();
        script.setTesting(true);
        (oracle) = script.deploy();

        console2.log("=== OraclePrice ===");
        console2.log("");
        ( ,uint256 price) = oracle.peek(bytes(""));
        console2.log("price", price);
    }
}