// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/Registry.s.sol";

contract MyTest is BaseTest {
    Registry public registry;

    function setUp() public override {
        forkMainnet(16666616);
        super.setUp();

        RegistryScript script = new RegistryScript();
        script.setTesting(true);
        (registry) = script.run();
    }

    function test() public {
        pushPrank(registry.owner());

        string memory cauldronInfoEncoding = "(address,uint8,bool,uint256)";
        bytes32 cauldronBucketKey = keccak256(abi.encode("cauldrons"));
        bytes32 allBucketKey = registry.ALL_BUCKETNAME();

        registry.set(
            keccak256(abi.encode("cauldrons.magicAPE")),
            cauldronBucketKey,
            abi.encode(0x692887E8877C6Dd31593cda44c382DB5b289B684, 4, false, 16656455),
            cauldronInfoEncoding
        );
        registry.set(
            keccak256(abi.encode("cauldrons.stargate-USDT")),
            cauldronBucketKey,
            abi.encode(0xc6B2b3fE7c3D7a6f823D9106E22e66660709001e, 3, false, 14744293),
            cauldronInfoEncoding
        );
        registry.set(keccak256(abi.encode("tokens.ape")), "", abi.encode(0x4d224452801ACEd8B2F0aebE155379bb5D594381), cauldronInfoEncoding);
        Registry.Entry[] memory cauldrons = registry.getMany(cauldronBucketKey);

        assertEq(cauldrons.length, 2);

        (address cauldron, uint8 version, bool deprecated, uint256 creationBlock) = abi.decode(
            cauldrons[0].content,
            (address, uint8, bool, uint256)
        );

        assertEq(cauldrons[0].key, keccak256(abi.encode("cauldrons.magicAPE")));
        assertEq(cauldron, 0x692887E8877C6Dd31593cda44c382DB5b289B684);
        assertEq(version, 4);
        assertEq(deprecated, false);
        assertEq(creationBlock, 16656455);
        assertEq(cauldrons[0].encoding, cauldronInfoEncoding);

        (cauldron, version, deprecated, creationBlock) = abi.decode(cauldrons[1].content, (address, uint8, bool, uint256));

        assertEq(cauldrons[1].key, keccak256(abi.encode("cauldrons.stargate-USDT")));
        assertEq(cauldron, 0xc6B2b3fE7c3D7a6f823D9106E22e66660709001e);
        assertEq(version, 3);
        assertEq(deprecated, false);
        assertEq(creationBlock, 14744293);
        assertEq(cauldrons[1].encoding, cauldronInfoEncoding);

        assertEq(registry.getBucketSize(allBucketKey), 3); // the 2 cauldrons + the ape token
        assertEq(registry.getBucketSize(cauldronBucketKey), 2); // the 2 cauldrons

        vm.expectRevert();
        registry.removeFromBucket(keccak256(abi.encode("cauldrons.stargate-USDT")), allBucketKey);

        registry.removeFromBucket(keccak256(abi.encode("cauldrons.stargate-USDT")), cauldronBucketKey);
        assertEq(registry.getBucketSize(allBucketKey), 3);
        assertEq(registry.getBucketSize(cauldronBucketKey), 1);

        cauldrons = registry.getMany(cauldronBucketKey);
        assertEq(cauldrons[0].key, keccak256(abi.encode("cauldrons.magicAPE")));

        vm.expectRevert();
        registry.clearBucket(allBucketKey);

        registry.clearBucket(cauldronBucketKey);
        assertEq(registry.getBucketSize(cauldronBucketKey), 0);

        popPrank();
    }
}
