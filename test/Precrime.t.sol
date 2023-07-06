// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/PreCrime.s.sol";
import "interfaces/ILzApp.sol";
import "interfaces/ILzOFTV2.sol";

contract PrecrimeTestBase is BaseTest {
    PreCrimeView precrime;
    BaseOFTV2View oftView;
    ILzOFTV2 oft;

    function initialize(uint256 chainId, uint256 blockNumber) public returns (PreCrimeScript script) {
        fork(chainId, blockNumber);
        super.setUp();

        script = new PreCrimeScript();
        script.setTesting(true);
    }

    function afterDeployed() public {
        oft = ILzOFTV2(constants.getAddress("oftv2", block.chainid));
    }
}

contract MainnetPrecrimeTest is PrecrimeTestBase {
    function setUp() public override {
        PreCrimeScript script = super.initialize(ChainId.Mainnet, 17629485);
        (precrime, oftView) = script.deploy();

        super.afterDeployed();
    }
}
