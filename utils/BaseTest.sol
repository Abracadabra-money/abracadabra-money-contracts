// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./Constants.sol";

abstract contract BaseTest is Test {
    Constants internal constants;
    bytes32 internal constant nextUser = keccak256(abi.encodePacked("user address"));

    address payable internal alice;
    address payable internal bob;
    address payable internal carol;

    function setUp() public virtual {
        alice = createUser("alice");
        bob = createUser("bob");
        carol = createUser("carol");
        constants = new Constants();
    }

    function createUser(string memory label) internal returns (address payable) {
        address payable user = payable(address(uint160(uint256(nextUser))));
        vm.deal(user, 100 ether);
        vm.label(user, label);
        return user;
    }

    function advanceBlocks(uint256 delta) internal returns (uint256 blockNumber) {
        blockNumber = block.number + delta;
        vm.roll(blockNumber);
    }

    function advanceTime(uint256 delta) internal returns (uint256 timestamp) {
        timestamp = block.timestamp + delta;
        vm.warp(timestamp);
    }
}
