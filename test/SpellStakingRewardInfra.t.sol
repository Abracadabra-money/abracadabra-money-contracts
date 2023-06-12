// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/SpellStakingRewardInfra.s.sol";

contract SpellStakingRewardInfraTestBase is BaseTest {
    CauldronFeeWithdrawer withdrawer;
    SpellStakingRewardDistributor distributor;

    function initialize(uint256 chainId, uint256 blockNumber) public returns (SpellStakingRewardInfraScript script) {
        fork(chainId, blockNumber);
        super.setUp();

        script = new SpellStakingRewardInfraScript();
        script.setTesting(true);
    }

    function afterDeployed() public {}

    function test() public {
        console2.log("test");
    }
}

contract MainnetSpellStakingInfraTest is SpellStakingRewardInfraTestBase {
    function setUp() public override {
        SpellStakingRewardInfraScript script = super.initialize(ChainId.Mainnet, 17465510);
        (withdrawer, distributor) = script.deploy();
        super.afterDeployed();

        console2.log("withdrawer", address(withdrawer));
        console2.log("distributor", address(distributor));
    }
}

contract AvalancheSpellStakingInfraTest is SpellStakingRewardInfraTestBase {
    function setUp() public override {
        SpellStakingRewardInfraScript script = super.initialize(ChainId.Avalanche, 31247693);
        (withdrawer, distributor) = script.deploy();

        console2.log("withdrawer", address(withdrawer));
        console2.log("distributor", address(distributor));

        super.afterDeployed();
    }
}
