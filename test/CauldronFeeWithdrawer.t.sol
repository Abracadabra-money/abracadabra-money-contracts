// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/CauldronFeeWithdrawer.s.sol";

contract CauldronFeeWithdrawerTest is BaseTest {
    CauldronFeeWithdrawer public withdrawer;

    function setUp() public override {
        forkMainnet(15979493);
        super.setUp();

        CauldronFeeWithdrawerScript script = new CauldronFeeWithdrawerScript();
        script.setTesting(true);
        withdrawer = script.run();
    }

    function test() public {
        
    }
}
