// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "forge-std/console2.sol";
import "solady/utils/ERC1967Factory.sol";

contract ImplementationStorageV1 {
    uint8 version;
    uint256 public slot1;
    uint256 public slot2;
}

contract ImplementationStorageV2 is ImplementationStorageV1 {
    address public slot3;
    uint256 public slot4;
}

contract ImplementatonV1 is ImplementationStorageV1 {
    // should not be called when deploying with the proxy factory.
    constructor() {
        slot1 = 1;
        slot2 = 2;
    }

    function init() external {
        assert(version == 0);
        slot1 = 3;
        slot2 = 4;
        version = 1;
    }
}

contract ImplementatonV2 is ImplementationStorageV2 {
    function init() external {
        assert(version == 1);
        slot1 = 5;
        slot2 = 6;
        version = 2;
    }
}

contract ERC1967FactoryTest is BaseTest {
    function test() public {
        ERC1967Factory factory = new ERC1967Factory();

        address impl1 = address(new ImplementatonV1());
        address impl2 = address(new ImplementatonV2());

        address proxy = factory.deploy(impl1, address(this));

        // constructors are not called
        assertEq(ImplementatonV1(proxy).slot1(), 0);
        assertEq(ImplementatonV1(proxy).slot2(), 0);

        proxy = factory.deployAndCall(impl1, address(this), abi.encodeWithSelector(ImplementatonV1.init.selector));
        assertEq(ImplementatonV1(proxy).slot1(), 3);
        assertEq(ImplementatonV1(proxy).slot2(), 4);

        factory.upgradeAndCall(proxy, impl2, abi.encodeWithSelector(ImplementatonV2.init.selector));
        assertEq(ImplementatonV1(proxy).slot1(), 5);
        assertEq(ImplementatonV1(proxy).slot2(), 6);
    }
}
