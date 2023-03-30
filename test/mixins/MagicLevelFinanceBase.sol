// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MagicLevelFinance.s.sol";

contract MagicLevelRewardHandlerV2Mock is MagicLevelRewardHandlerDataV1 {
    uint256 public newSlot;

    function handleFunctionWithANewName(uint256 param1, ILevelFinanceStaking _staking, string memory _name) external {
        newSlot = param1;
        name = _name;
        staking = _staking;
    }
}

contract MagicLevelFinanceTestBase is BaseTest {
    event LogRewardHandlerChanged(IMagicLevelRewardHandler indexed previous, IMagicLevelRewardHandler indexed current);

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

    function _generateRewards(uint256 lvlAmount) internal {}

    function _testRewardHarvesting() internal {}

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

    function testUpgradeRewardHandler() internal {
        MagicLevelRewardHandlerV2Mock newHandler = new MagicLevelRewardHandlerV2Mock();
        IMagicLevelRewardHandler previousHandler = IMagicLevelRewardHandler(vault.rewardHandler());

        vm.startPrank(vault.owner());
        MagicLevelRewardHandler(address(vault)).harvest(address(this));

        // check random slot storage value for handler and wrapper
        (ILevelFinanceStaking previousValue1, ) = IMagicLevelRewardHandler(address(vault)).stakingInfo();
        string memory previousValue2 = vault.name();

        // upgrade the handler
        vm.expectEmit(true, true, true, true);
        emit LogRewardHandlerChanged(previousHandler, IMagicLevelRewardHandler(address(newHandler)));
        vault.setRewardHandler(IMagicLevelRewardHandler(address(newHandler)));

        (ILevelFinanceStaking staking, ) = IMagicLevelRewardHandler(address(vault)).stakingInfo();
        assertEq(address(staking), address(previousValue1));
        assertEq(vault.name(), previousValue2);

        MagicLevelRewardHandlerV2Mock(address(vault)).handleFunctionWithANewName(111, ILevelFinanceStaking(address(0)), "abracadabra");

        (staking, ) = IMagicLevelRewardHandler(address(vault)).stakingInfo();

        assertEq(address(staking), address(0));
        assertEq(vault.name(), "abracadabra");
        assertEq(MagicLevelRewardHandlerV2Mock(address(vault)).newSlot(), 111);
        vm.stopPrank();
    }
}
