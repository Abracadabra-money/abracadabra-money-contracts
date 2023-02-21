// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/libraries/BoringERC20.sol";
import "utils/BaseTest.sol";
import "script/AbracadabraRegistry.s.sol";

contract AbracadabraRegistryTest is BaseTest {
    AbracadabraRegistry registry;

    function setUp() public override {
        forkArbitrum(61030822);
        super.setUp();

        AbracadabraRegistryScript script = new AbracadabraRegistryScript();
        script.setTesting(true);
        registry = script.run();
    }

    function testSet() public {
        pushPrank(registry.owner());
        registry.set("markets", "QmcCagY5QJVQBGKWUfaj8zahAJWNGY5Fje35YJ9BNiQpRU");
        assertEq(registry.get("markets"), "QmcCagY5QJVQBGKWUfaj8zahAJWNGY5Fje35YJ9BNiQpRU");
    }

    function testGetUnknownKey() public {
        vm.expectRevert(abi.encodeWithSignature("ErrKeyNotFound()"));
        registry.get("markets");
    }
}
