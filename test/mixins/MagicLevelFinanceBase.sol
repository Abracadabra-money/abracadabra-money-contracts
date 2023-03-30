// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MagicLevelFinance.s.sol";

contract MagicLevelFinanceTestBase is BaseTest {
    MagicLevelFinanceScript script;
    ProxyOracle oracle;
    MagicLevel vault;

    // expectations
    uint256 expectedOraclePrice;

    function initialize(uint256 _expectedOraclePrice) public virtual {
        forkBSC(26916543);
        super.setUp();

        script = new MagicLevelFinanceScript();
        script.setTesting(true);

        expectedOraclePrice = _expectedOraclePrice;
    }

    function testOracle() public {
        assertEq(oracle.peekSpot(""), expectedOraclePrice);
    }

    function testProtectedDepositAndWithdrawFunctions() public {
        // it should never be possible to call deposit and withdraw directly
        vm.expectRevert(abi.encodeWithSignature("ErrNotVault()"));
        IMagicLevelRewardHandler(address(vault)).deposit(123);

        vm.expectRevert(abi.encodeWithSignature("ErrNotVault()"));
        IMagicLevelRewardHandler(address(vault)).withdraw(123);

        // call throught fallback function from EOA
        {
            bytes memory data = abi.encodeWithSelector(MagicLevelRewardHandler.deposit.selector, 123);
            vm.expectRevert(abi.encodeWithSignature("ErrNotVault()"));
            (bool success, ) = address(vault).call{value: 0}(data);
            assertFalse(success);
        }

        {
            bytes memory data = abi.encodeWithSelector(MagicLevelRewardHandler.withdraw.selector, 123);
            vm.expectRevert(abi.encodeWithSignature("ErrNotVault()"));
            (bool success, ) = address(vault).call{value: 0}(data);
            assertFalse(success);
        }
    }
}
