// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/SpellLayerZero.s.sol";

contract SpellLayerZeroTestBase is BaseTest {
    LzProxyOFTV2 proxyOFTV2;
    LzIndirectOFTV2 indirectOFTV2;
    address spell;

    function initialize(uint256 chainId, uint256 blockNumber) public returns (SpellLayerZeroScript script) {
        fork(chainId, blockNumber);
        super.setUp();

        script = new SpellLayerZeroScript();
        script.setTesting(true);
    }

    function afterDeployed() public {}
}

contract SpellLayerZeroMainnetTest is SpellLayerZeroTestBase {
    function setUp() public override {
        SpellLayerZeroScript script = super.initialize(ChainId.Mainnet, 20230082);
        (proxyOFTV2, indirectOFTV2, spell) = script.deploy();
        super.afterDeployed();
    }

    function testDeployment() public view {
        assertNotEq(address(proxyOFTV2), address(0));
        assertEq(address(indirectOFTV2), address(0));
        assertEq(spell, toolkit.getAddress(ChainId.Mainnet, "spell"));
    }
}

contract SpellLayerZeroArbitrumTest is SpellLayerZeroTestBase {
    function setUp() public override {
        SpellLayerZeroScript script = super.initialize(ChainId.Arbitrum, 228524027);
        (proxyOFTV2, indirectOFTV2, spell) = script.deploy();
        super.afterDeployed();
    }

    function testDeployment() public view {
        assertEq(address(proxyOFTV2), address(0));
        assertNotEq(address(indirectOFTV2), address(0));
        assertNotEq(spell, toolkit.getAddress(ChainId.Arbitrum, "spell"));
    }
}