// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MIMLayerZero.s.sol";

contract MIMLayerZeroTestBase is BaseTest {
    MIMLayerZeroScript script;

    function initialize(uint256 chainId, uint256 blockNumber) public {
        fork(chainId, blockNumber);
        super.setUp();

        script = new MIMLayerZeroScript();
        script.setTesting(true);
    }

    function afterDeployed() public {}
}

contract MIMLayerZeroTest is MIMLayerZeroTestBase {
    function setUp() public override {
        super.initialize(ChainId.Mainnet, 17293430);
        script.deploy();
        super.afterDeployed();
    }
}
